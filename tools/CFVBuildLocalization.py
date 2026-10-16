import pathlib,re,json
root=pathlib.Path(__file__).resolve().parents[1]/'Crealfanvar'
entries={}
pattern=r'CFVText\("((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)'
for path in root.rglob('*.swift'):
    for zh,en in re.findall(pattern,path.read_text()):entries[en+"|"+zh]=(en,zh)
# Runtime level titles, creature names, and accessible shape/direction names.
for path in (root/'Resources/Levels').glob('*.json'):
    d=json.loads(path.read_text());entries[d['titleEN']+'|'+d['titleZH']]=(d['titleEN'],d['titleZH']);entries[d['purposeEN']+'|'+d['purposeZH']]=(d['purposeEN'],d['purposeZH'])
for en,zh in [('Paper Butterfly','纸蝶'),('Folded Bird','折翼鸟'),('Paper Fish','纸鱼'),('Paper Rabbit','纸兔'),('Paper Fox','纸狐'),('Paper Deer','纸鹿'),('leaf','叶片'),('triangle','三角'),('circle','圆纹'),('Swap left','向左交换'),('Swap right','向右交换'),('Swap up','向上交换'),('Swap down','向下交换')]:entries[en+"|"+zh]=(en,zh)
for chapter in json.loads((root/'Resources/CFV-Release-Catalog.json').read_text())['learningStages']:
    en,zh=chapter['nameEN'],chapter['name'];entries[en+'|'+zh]=(en,zh)
for code in ['en','zh-Hans']:
    d=root/'Resources'/f'{code}.lproj';d.mkdir(exist_ok=True)
    (d/'Localizable.strings').write_text('\n'.join('"'+key+'" = "'+(zh if code=='zh-Hans' else en)+'";' for key,(en,zh) in sorted(entries.items()))+'\n')
print(f'{len(entries)} localization entries per language')
