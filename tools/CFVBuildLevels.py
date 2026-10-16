"""Offline authoring aid. Fixed seeds, selected mechanics, validated by production Swift.
No runtime randomness. Each final JSON is a frozen authored puzzle."""
import json, random, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
random.seed(20261015)
F = lambda side, k: dict(creaseID=f'{side}-{k}', axis='vertical' if side in ('left','right') else 'horizontal', boundary=k, movingSide=side)
R1,R2,L2,B2,T2 = F('right',5),F('right',4),F('left',2),F('bottom',4),F('top',2)
def moving(i,f):
    x=i%6 if f['axis']=='vertical' else i//6
    return x<f['boundary'] if f['movingSide'] in ('left','top') else x>=f['boundary']
def project(f):
    p=list(range(36))
    if not f:return p
    for i in range(36):
        if moving(i,f):p[i]=None
    for i in range(36):
        if moving(i,f):
            d=i//6*6+2*f['boundary']-1-i%6 if f['axis']=='vertical' else (2*f['boundary']-1-i//6)*6+i%6
            p[d]=i
    return p
def matches(b,p=None):
    p=p or list(range(36)); out=set()
    for axis in range(2):
        for line in range(6):
            run=[]; last=None
            for x in range(7):
                i=(line*6+x if axis==0 else x*6+line) if x<6 else None
                src=p[i] if i is not None else None
                kind=b[src][0] if src is not None and b[src] else None
                if kind is None or kind!=last:
                    if len(run)>=3:out.update(run)
                    run=[]
                if kind:run.append(src)
                last=kind
    return out
def actions(b,folds,typ=None):
    out=[]
    if typ!='swap':
        for f in folds:
            rm=matches(b,project(f))
            if rm:out.append((dict(type='fold',creaseID=f['creaseID']),b[:],rm))
    if typ!='fold':
        for i in range(36):
            for j in ([i+1] if i%6<5 else [])+([i+6] if i<30 else []):
                if not b[i] or not b[j]:continue
                c=b[:];c[i],c[j]=c[j],c[i];rm=matches(c)
                if rm:out.append((dict(type='swap',first=i,second=j),c,rm))
    return out
def apply(c,rm):return [None if i in rm else t for i,t in enumerate(c)]
def solvable(b, targets, folds, depth, memo):
    if not any(t and t[1] in targets for t in b):return True
    if depth==0:return False
    key=(tuple(b),depth)
    if key in memo:return False
    memo.add(key)
    for a,c,rm in actions(b,folds):
        if solvable(apply(c,rm),targets,folds,depth-1,memo):return True
    return False
specs=[
('初见菱形','A little diamond','交换高亮的相邻图案，让菱形目标加入三连。','Swap the highlighted neighbors to match the diamond target.',[],['swap']),
('折起一角','The first fold','点按右侧折痕。先取消预览，再确认一次折叠。','Tap the right crease. Cancel the preview, then preview and confirm.',[R2],['fold']),
('表面之下','Beneath the surface','折叠只消除最上层图案。展开后，找出留下的目标。','Only the top layer matches. Find the target that remains after unfolding.',[L2],['fold','swap']),
('再试一次','Another possibility','预览两条折痕，比较结果。可以撤销已提交的动作，再选择路线。','Compare both creases. Undo a committed move to try another route.',[R2,T2],['swap','fold']),
('先换后折','Before the fold','先交换，安排折后相邻的图案，再沿右侧折痕折叠。','Swap first to arrange the surface, then fold from the right.',[R2],['swap','fold']),
('向上相遇','Meeting above','从下边缘向上折。横向折痕也遵循同样的遮挡规则。','Fold upward from the bottom. The same overlap rule applies.',[B2],['fold','swap']),
('一列或两列','One or two','比较右侧一列与两列的投影。每次只折一个面。','Compare the one-column and two-column creases. Fold one at a time.',[R1,R2],['fold','swap']),
('换个方向','A different direction','水平与竖直折叠有不同的表面。先检查，再行动。','Horizontal and vertical folds reveal different surfaces. Look before committing.',[L2,B2],['fold','fold']),
('留白也有重量','The weight of blank paper','空白纸格仍遮挡下层。预览并取消，看看哪些目标被盖住。','Blank paper still covers tiles. Preview and cancel to inspect the hidden targets.',[R2,T2],['swap','fold','fold']),
('留下关键一枚','Save a key piece','并非每次三消都有帮助。保留后续折叠需要的图案。','Not every match helps. Save the patterns needed by a later fold.',[R2,B2],['swap','fold','swap']),
('散落的星点','Scattered diamonds','目标分布在不同位置。在三步之内让它们相遇。','Targets are scattered across the paper. Reach them in three moves.',[L2,B2],['fold','swap','fold']),
('最后一页','The final page','安排交换、折叠和遮挡顺序，展开最后一只纸鹿。','Plan swaps, folds and overlaps to unfold the final paper deer.',[R2,T2],['swap','fold','swap','fold'])]
def main():
    report=[]
    for n,(zh,en,pzh,pen,folds,sequence) in enumerate(specs,1):
        for attempt in range(25000):
            b=[(random.choice('LTC'),i) for i in range(36)]
            if n==9:
                for i in (4,10,29):b[i]=None
            if matches(b):continue
            current=b[:];path=[];removed=[];states=[b[:]]
            for typ in sequence:
                opts=actions(current,folds,typ)
                if not opts:break
                a,c,rm=random.choice(opts)
                ids=[c[i][1] for i in rm]
                path.append(a);removed.append(ids);current=apply(c,rm);states.append(current)
            if len(path)!=len(sequence):continue
            if n==5 and path[-1]['creaseID'] in [a['creaseID'] for a,c,r in actions(b,folds,'fold')]:continue
            if n==7 and len(actions(b,folds,'fold'))!=1:continue
            if n in (8,9,12) and path[-1].get('creaseID')==path[-2].get('creaseID'):continue
            targets=[random.choice(ids) for ids in removed]
            if n>=9:
                targets+=random.sample(removed[-1],min(2,len(removed[-1])))
            targets=sorted(set(targets))
            if n==3:
                f=folds[0]; hidden=set(range(36))-set(x for x in project(f) if x is not None)-set(i for i in range(36) if moving(i,f))
                possible=set(removed[1])&hidden
                if not possible:continue
                targets=[random.choice(removed[0]),random.choice(sorted(possible))]
            if n==9:
                covered=[i for i in range(36) if not moving(i,R2) and project(R2)[i] is not None and b[project(R2)[i]] is None and b[i]]
                if not covered:continue
                if not any(i in sum(removed,[]) for i in covered):continue
                targets=sorted(set(targets+[next(i for i in covered if i in sum(removed,[]))]))
            if n>=4 and solvable(b,set(targets),folds,len(sequence)-1,set()):continue
            # Save a concrete tempting branch which cannot win within the remaining budget.
            trap=None
            if n in (4,10,12):
                for a,c,rm in actions(b,folds):
                    if a!=path[0] and not solvable(apply(c,rm),set(targets),folds,len(sequence)-1,set()):trap=a;break
                if trap is None:continue
            rows=[''.join(t[0] if t else '.' for t in b[r*6:r*6+6]) for r in range(6)]
            level=dict(levelID=f'level-{n:02}',contentVersion=1,rulesVersion=1,learningStage=['first-folds','new-directions','clever-overlaps'][(n-1)//4],titleZH=zh,titleEN=en,purposeZH=pzh,purposeEN=pen,initialRows=rows,targetCells=targets,moveLimit=len(sequence),folds=folds,referenceSolution=path,tutorialCells=[path[0]['first'],path[0]['second']] if path[0]['type']=='swap' else [],tutorialCrease=path[0].get('creaseID'))
            (ROOT/'Crealfanvar/Resources/Levels'/f'CFV-Level-{n:02}.json').write_text(json.dumps(level,ensure_ascii=False,indent=2)+'\n')
            report.append(dict(level=n,attempt=attempt,targets=targets,solution=path,temptingLosingAction=trap,initialBlankCoveredTargets=covered if n==9 else []))
            print(n,rows,targets,path,flush=True)
            break
        else:raise RuntimeError(f'No design for {n}')
    (ROOT/'artifacts/validation/CFV-Level-Design-Witnesses.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))

if __name__ == "__main__":
    main()
