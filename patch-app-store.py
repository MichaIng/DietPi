#!/usr/bin/env python3
"""Apply/revert the fork's small first-run App Store hook, never run installers."""
import argparse,hashlib,json,os
from pathlib import Path
import stat,subprocess,tempfile,time

ANCHOR='\t\t# Custom 1st run script\n'
HOOK='''\t\t# Fork integration: install App Store once, without changing custom scripts.
\t\tif [[ -f /boot/dietpi/func/install-pi-app-store ]]
\t\tthen
\t\t\tbash /boot/dietpi/func/install-pi-app-store || G_DIETPI-NOTIFY 1 'Pi App Store setup failed; continuing DietPi setup.'
\t\tfi

'''
def digest(data):return hashlib.sha256(data).hexdigest()
def read_regular(path):
 if path.is_symlink():raise ValueError('Refusing symlink.')
 st=path.stat()
 if not stat.S_ISREG(st.st_mode):raise ValueError('Not a regular file.')
 return path.read_bytes(),st

def replace(path,before,after,st):
 if path.read_bytes()!=before:raise ValueError('Target changed. Nothing replaced.')
 fd,tmp=tempfile.mkstemp(prefix='.dietpi-store-patch-',dir=path.parent)
 try:
  os.fchmod(fd,stat.S_IMODE(st.st_mode));os.fchown(fd,st.st_uid,st.st_gid)
  with os.fdopen(fd,'wb') as f:f.write(after);f.flush();os.fsync(f.fileno())
  result=subprocess.run(['bash','-n',tmp],capture_output=True)
  if result.returncode:raise ValueError('Bash syntax check failed. Nothing replaced.')
  if path.read_bytes()!=before:raise ValueError('Target changed before replacement.')
  os.replace(tmp,path)
 finally:
  if os.path.exists(tmp):os.unlink(tmp)

def apply(path):
 raw,st=read_regular(path);text=raw.decode('utf-8')
 if HOOK in text:print('Hook already installed. No changes.');return None
 if 'Fork integration: install App Store' in text:raise ValueError('Different hook exists; review manually.')
 if text.count(ANCHOR)!=1:raise ValueError('Expected unique custom-script anchor not found. No changes.')
 start=text.find('DietPi-Automation_Post()');end=text.find('# Globals',start)
 if start<0 or end<0 or not start<text.index(ANCHOR)<end:raise ValueError('Anchor outside first-run function. No changes.')
 after=text.replace(ANCHOR,HOOK+ANCHOR).encode('utf-8')
 backup=path.with_name(path.name+'.before-appstore-'+str(time.time_ns()))
 with backup.open('xb') as f:f.write(raw)
 backup.chmod(0o600)
 manifest=backup.with_suffix(backup.suffix+'.json')
 with manifest.open('x') as f:json.dump({'target':str(path.resolve()),'before_sha256':digest(raw),'after_sha256':digest(after)},f)
 manifest.chmod(0o600)
 replace(path,raw,after,st)
 print('Hook applied; installer was NOT run. Backup:',backup);return backup

def revert(path,backup):
 raw,st=read_regular(path);old,_=read_regular(backup);meta=json.loads(backup.with_suffix(backup.suffix+'.json').read_text())
 if meta['target']!=str(path.resolve()) or digest(old)!=meta['before_sha256'] or digest(raw)!=meta['after_sha256']:raise ValueError('Target or backup changed. Refusing revert; review manually.')
 replace(path,raw,old,st);print('Original file restored. Helper/Store not removed.')
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=('apply','revert'));p.add_argument('--file',default='/boot/dietpi/dietpi-software');p.add_argument('--backup');a=p.parse_args();path=Path(a.file).absolute()
 if a.file=='/boot/dietpi/dietpi-software' and os.geteuid()!=0:raise ValueError('Run as root on DietPi.')
 if a.action=='apply':apply(path)
 elif a.backup:revert(path,Path(a.backup).absolute())
 else:raise ValueError('Revert needs --backup with the printed backup path.')
if __name__=='__main__':
 try:main()
 except (OSError,ValueError,KeyError,UnicodeError) as e:print('Stopped:',e);raise SystemExit(1)
