from pathlib import Path
import re
root=Path(__file__).resolve().parent.parent
errors=[];count=0
for p in list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart')):
 s=p.read_text();count+=1
 for imp in re.findall(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''',s):
  if imp.startswith(('dart:','package:flutter','package:characters','package:collection','package:shared_preferences','package:provider','package:supabase','package:google','package:uuid','package:http','package:crypto','package:intl','package:flame','package:path','package:equatable','package:audio','package:just_audio','package:mock','package:test','package:flutter_test','package:vector','package:cupertino','package:material','package:logging','package:meta','package:sqlite','package:drift','package:connectivity','package:device','package:package_info','package:firebase','package:permission','package:window','package:universal','package:screen','package:wakelock','package:video','package:file','package:image','package:cross','package:archive','package:visibility','package:logging','package:clock')):continue
  if imp.startswith('package:ballwars/'):target=root/'lib'/imp[len('package:ballwars/'):]
  elif imp.startswith('package:'):continue
  else:target=p.parent/imp
  if not target.is_file():errors.append((str(p.relative_to(root)),imp))
print('Dart files:',count,'Missing local imports:',len(errors))
for e in errors[:100]:print(*e)
