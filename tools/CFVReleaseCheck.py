"""Validate a built archive and report genuine external release blockers."""
import argparse, pathlib, json, plistlib, sys
root=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app',type=pathlib.Path,default=root/'artifacts/CFV-Paperkin-Motion-Unsigned.xcarchive/Products/Applications/Crealfanvar.app')
parser.add_argument('--strict',action='store_true')
arguments=parser.parse_args()
app=arguments.app
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.tumopa.Crealfanvar'
assert info['MinimumOSVersion']=='15.0'
assert info['UIDeviceFamily']==[1]
assert info['UISupportedInterfaceOrientations']==['UIInterfaceOrientationPortrait']
assert len(list(app.glob('CFV-Level-*.json')))==12
assert len(list(app.glob('CFV-paper-*.png')))+len(list(app.glob('CFV-folded-bird-*.png')))==18
assert len(list(app.glob('CFV-*.wav')))==7
assert (app/'PrivacyInfo.xcprivacy').exists()
for language in ['en','zh-Hans']:assert (app/(language+'.lproj')/'Localizable.strings').exists()
assert not list(app.glob('*.png')) or (app/'Assets.car').exists()
report=dict(bundleID=info['CFBundleIdentifier'],minimumOS=info['MinimumOSVersion'],sdk=info['DTSDKName'],xcode=info['DTXcode'],levels=12,creatures=6,stages=18,audioFiles=7,bundleBytes=sum(p.stat().st_size for p in app.rglob('*') if p.is_file()),signed=False,uploaded=False)
report['externalBlockers']=['Developer signing identity and provisioning','Real-device iOS 15 and current-system QA','VoiceOver task completion and audio interruption on device','First-time-user observation (5–8 people, two rounds for levels 1–4 and blank-paper comprehension)','Instruments performance and long-session memory measurements','TestFlight regression and signed upload validation','Developer identity, name rights, regions and applicable regional materials','App Store age rating, pricing, privacy labels and final screenshot selection']
for key in ['CFVPrivacyURL','CFVSupportURL']:
    if not info.get(key,'').startswith('https://'):report['externalBlockers'].append('Missing genuine HTTPS '+key)
(root/'artifacts/validation').mkdir(parents=True,exist_ok=True)
(root/'artifacts/validation/CFV-Release-Preflight.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert report['bundleBytes'] <= 12 * 1024 * 1024, 'App exceeds the 12 MiB uncompressed size budget'
if arguments.strict and report['externalBlockers']:sys.exit(1)
