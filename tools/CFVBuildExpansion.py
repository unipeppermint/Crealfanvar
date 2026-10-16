"""Author frozen levels 13–24; never rewrite the original twelve puzzles.

Each accepted board has a replayable witness, an exact shortest-move proof and
at least one legal but losing opening. Budget exhaustion rejects a candidate.
Run offline with Python's standard library, then run CFVRunCoreTests.sh.
"""
import hashlib
import json
import pathlib
import random
import time
from functools import lru_cache
from CFVBuildLevels import F, actions, apply, matches, project

ROOT = pathlib.Path(__file__).resolve().parents[1]
LEVELS = ROOT / 'Crealfanvar/Resources/Levels'
PAIRS = [(i, j) for i in range(36) for j in ([i+1] if i%6<5 else [])+([i+6] if i<30 else [])]
TRIPLES = [(r*6+c, r*6+c+1, r*6+c+2) for r in range(6) for c in range(4)] + [(r*6+c, (r+1)*6+c, (r+2)*6+c) for r in range(4) for c in range(6)]


def removed(board, projection=tuple(range(36))):
    surface = [board[i] if i is not None else 0 for i in projection]
    cells = set()
    for a,b,c in TRIPLES:
        kind = surface[a] & 3
        if kind and kind == surface[b]&3 == surface[c]&3:
            cells.update((projection[a],projection[b],projection[c]))
    return cells


class BudgetExceeded(Exception):
    pass


class Proof:
    def __init__(self, folds):
        self.projections = [(f, project(f)) for f in folds]
        self.nodes = 0
        self.deadline = time.monotonic() + 12

    @lru_cache(maxsize=40000)
    def turns(self, board):
        result = []
        for fold, projection in self.projections:
            rm = removed(board, projection)
            if rm:
                result.append((dict(type='fold',creaseID=fold['creaseID']), tuple(0 if i in rm else t for i,t in enumerate(board))))
        for first,second in PAIRS:
            if not board[first] or not board[second] or (board[first]&3)==(board[second]&3):
                continue
            changed = list(board)
            changed[first],changed[second] = changed[second],changed[first]
            rm = removed(changed)
            if rm:
                result.append((dict(type='swap',first=first,second=second),tuple(0 if i in rm else t for i,t in enumerate(changed))))
        return result

    @lru_cache(maxsize=150000)
    def wins(self, board, depth):
        if not any(t&4 for t in board):
            return True
        if not depth:
            return False
        self.nodes += 1
        if self.nodes > 30000 or time.monotonic() > self.deadline:
            raise BudgetExceeded()
        for kind in (1,2,3):
            if any(t == kind+4 for t in board) and sum((t&3)==kind for t in board)<3:
                return False
        for _, next_board in self.turns(board):
            if self.wins(next_board,depth-1):
                return True
        return False

    def clear(self):
        self.turns.cache_clear()
        self.wins.cache_clear()


CHAPTERS = [
    ('edge-whispers','纸边微光','Paper edges','paper-butterfly'),
    ('winding-folds','回环折痕','Winding folds','paper-fox'),
    ('deep-forest','森林深处','Deep forest','paper-deer'),
]
# Narrow and two-column folds create a matching seam. A full half-sheet covers
# that seam entirely, so it cannot create a new match on these match-free boards.
SPECS = [
('窄边来信','A narrow note','先整理边缘图案，再比较一列与两列的折面。','Arrange the edge patterns, then compare one-column and two-column folds.',[F('right',5),F('left',2)],'sfsf',0),
('上下呼应','Above and below','上下两条窄折痕会覆盖不同的目标。','The two horizontal folds cover different targets.',[F('top',1),F('bottom',4)],'fssf',1),
('错开的叶影','Offset leaves','目标不在同一条线上，交换为后续折叠留出图案。','Targets sit on different lines. Keep patterns for the later fold.',[F('left',1),F('bottom',4)],'sfss',2),
('边缘留白','Blank edges','有空白的折面仍会盖住下层，先预览再安排顺序。','Blank folded cells still cover the lower layer. Preview before choosing an order.',[F('right',4),F('top',1)],'sfsf',3),
('双向足迹','Two-way tracks','看似能消除的开局，不一定能清完所有目标。','An opening match may leave targets unreachable. Compare the routes.',[F('right',4),F('top',2)],'sfsfs',0),
('藏在涟漪下','Under the ripples','先清理表面，再沿另一条折痕寻找留下的目标。','Clear the surface, then use the other crease to reach the remaining targets.',[F('bottom',4),F('left',1)],'fssfs',1),
('一枚伏笔','One piece for later','交换不能跨过空格，保留后续折叠需要的图案。','Swaps cannot cross empty cells. Keep patterns needed for later folds.',[F('left',2),F('right',5)],'ssfss',2),
('回身一折','A returning fold','折后展开不是补充，重新观察剩下的相邻关系。','Unfolding adds no new tiles. Inspect the neighbors that remain.',[F('top',1),F('bottom',4)],'sfsfs',0),
('层间微光','Light between layers','六步之内完成目标，每次预览都检查目标所在层。','Finish in six moves. Inspect the target layer in every preview.',[F('right',4),F('top',2)],'sfsfss',0),
('远处的星点','Distant diamonds','目标散落在纸面两侧，用六步把它们全部找回。','Targets lie on both sides of the paper. Reach them all in six moves.',[F('left',2),F('bottom',4)],'fsfsss',1),
('最后的留白','The last blank','空白层会改变每次投影，确认前检查最后一组图案。','Blank layers change each projection. Inspect the final group before committing.',[F('right',5),F('bottom',4)],'ssfsfs',2),
('森林长卷','The forest unfolds','综合安排六步。随时预览、撤销，让整段旅程从容展开。','Plan all six moves. Preview and undo freely as the journey unfolds.',[F('left',2),F('top',2)],'sfsfss',0),
]


def main():
    baseline = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(LEVELS.glob('*.json')) if int(p.stem[-2:])<=12}
    report = []
    for offset,(zh,en,pzh,pen,folds,sequence,blanks) in enumerate(SPECS):
        number = offset+13
        rng = random.Random(2026101600+number)
        accepted = False
        for attempt in range(100000):
            board = [(rng.choice('LTC'),i) for i in range(36)]
            for cell in rng.sample(range(36),blanks): board[cell]=None
            if matches(board): continue
            current=board[:]; path=[]; removals=[]
            for symbol in sequence:
                choices=actions(current,folds,'swap' if symbol=='s' else 'fold')
                if not choices: break
                action,changed,rm=rng.choice(choices)
                path.append(action);removals.append([changed[i][1] for i in sorted(rm)])
                current=apply(changed,rm)
            if len(path)!=len(sequence): continue
            used={a['creaseID'] for a in path if a['type']=='fold'}
            if sequence.count('f')>=2 and len(used)<2: continue
            targets=sorted({rng.choice(ids) for ids in removals} | set(rng.sample(removals[-1],min(2,len(removals[-1])))))
            if number >= 18:
                targets=sorted({target for ids in removals for target in rng.sample(ids,min(2,len(ids)))})
            encoded=tuple(0 if t is None else 'LTC'.index(t[0])+1+(4 if t[1] in targets else 0) for t in board)
            proof=Proof(folds)
            try:
                if proof.wins(encoded,len(sequence)-1): continue
                trap=next((a for a,nxt in proof.turns(encoded) if a!=path[0] and not proof.wins(nxt,len(sequence)-1)),None)
                if trap is None: continue
            except BudgetExceeded:
                continue
            finally:
                nodes=proof.nodes
                proof.clear()
            rows=[''.join(t[0] if t else '.' for t in board[r*6:r*6+6]) for r in range(6)]
            level=dict(levelID=f'level-{number:02}',contentVersion=1,rulesVersion=1,learningStage=CHAPTERS[offset//4][0],titleZH=zh,titleEN=en,purposeZH=pzh,purposeEN=pen,initialRows=rows,targetCells=targets,moveLimit=len(sequence),folds=folds,referenceSolution=path,tutorialCells=[],tutorialCrease=None)
            (LEVELS/f'CFV-Level-{number:02}.json').write_text(json.dumps(level,ensure_ascii=False,indent=2)+'\n')
            report.append(dict(level=number,attempt=attempt,minimumMoves=len(sequence),proofNodes=nodes,targets=targets,solution=path,temptingLosingAction=trap,initialBlankCount=blanks))
            print(f'{number}: {len(sequence)} moves, {len(targets)} targets, attempt {attempt}, proof {nodes} nodes',flush=True)
            accepted=True
            break
        if not accepted: raise RuntimeError(f'No accepted design for level {number}')
    assert baseline=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(LEVELS.glob('*.json')) if int(p.stem[-2:])<=12}
    (ROOT/'artifacts/validation/CFV-Expansion-Design-Witnesses.json').write_text(json.dumps(dict(originalLevelSHA256=baseline,levels=report),ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    main()
