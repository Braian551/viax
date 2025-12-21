from pathlib import Path
p=Path('lib/src/features/conductor/presentation/screens/conductor_searching_passengers_screen.dart')
s=p.read_text(encoding='utf-8')
open_count=s.count('(')
close_count=s.count(')')
open_braces=s.count('{')
close_braces=s.count('}')
print('paren_open',open_count,'paren_close',close_count)
print('braces_open',open_braces,'braces_close',close_braces)
# find first line where cumulative paren count goes negative (too many closes)
cum=0
neg_line=None
for i,line in enumerate(s.splitlines(),start=1):
    cum+=line.count('(')-line.count(')')
    if cum<0 and neg_line is None:
        neg_line=i
        break
print('first_negative', neg_line)
print('final cum',cum)
# dump cumulative near the end
lines=s.splitlines()
start=max(1,len(lines)-140)
cum=0
for i,line in enumerate(lines,start=1):
    cum+=line.count('(')-line.count(')')
    if i>=start and (line.count('(')+line.count(')'))>0:
        print(f"{i:4d} cum={cum:3d} | {line.strip()}")
