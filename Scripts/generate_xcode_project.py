#!/usr/bin/env python3
"""Generate the native, dependency-free Xcode project from local Swift sources."""
from pathlib import Path
import hashlib, json
from xml.sax.saxutils import escape
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def quote(value): return json.dumps(str(value))
def add(object_name, isa, **fields):
    key = ident(object_name)
    objects[key] = '{ isa = ' + isa + '; ' + ' '.join(k + ' = ' + v + ';' for k, v in fields.items()) + ' };'
    return key
def array(items): return '( ' + ', '.join(items) + ' )'
def settings(values): return '{ ' + ' '.join(k + ' = ' + (array([quote(x) for x in v]) if isinstance(v,list) else quote(v)) + ';' for k,v in values.items()) + ' }'
def file(path, kind): return add('file:'+path,'PBXFileReference',lastKnownFileType=quote(kind),path=quote(path),sourceTree=quote('SOURCE_ROOT'))
def source_group(folder):
    children=[]
    for path in sorted(folder.iterdir()):
        if path.is_dir() and path.name != 'Resources': children.append(source_group(path))
        elif path.suffix == '.swift': children.append(file(str(path.relative_to(root)), 'sourcecode.swift'))
    return add('group:'+str(folder.relative_to(root)), 'PBXGroup', children=array(children), name=quote(folder.name), sourceTree=quote('<group>'))
source_group_id=source_group(root/'Sources'/'Telex')
test_group_id=source_group(root/'Tests'/'TelexTests')
resources=[file('Sources/Telex/Resources/AppIcon.png', 'image.png'), file('Assets/AppIcon.icns', 'image.icns')]
resource_group=add('resourceGroup','PBXGroup',children=array(resources),name=quote('Artwork'),sourceTree=quote('<group>'))
configs=[file('Config/Info.plist','text.plist.xml'),file('Config/Telex.entitlements','text.plist.entitlements')]
config_group=add('configGroup','PBXGroup',children=array(configs),name=quote('Configuration'),sourceTree=quote('<group>'))
app_product=add('appProduct','PBXFileReference',explicitFileType=quote('wrapper.application'),includeInIndex='0',path=quote('Telex.app'),sourceTree=quote('BUILT_PRODUCTS_DIR'))
test_product=add('testProduct','PBXFileReference',explicitFileType=quote('wrapper.cfbundle'),includeInIndex='0',path=quote('TelexTests.xctest'),sourceTree=quote('BUILT_PRODUCTS_DIR'))
products=add('products','PBXGroup',children=array([app_product,test_product]),name=quote('Products'),sourceTree=quote('<group>'))
main_group=add('mainGroup','PBXGroup',children=array([source_group_id,test_group_id,resource_group,config_group,products]),sourceTree=quote('<group>'))
def phase(name,isa,refs):
    builds=[add('build:'+name+':'+ref,'PBXBuildFile',fileRef=ref) for ref in refs]
    return add(name,isa,buildActionMask='2147483647',files=array(builds),runOnlyForDeploymentPostprocessing='0')
app_sources=phase('appSources','PBXSourcesBuildPhase',[ident('file:'+str(p.relative_to(root))) for p in sorted((root/'Sources'/'Telex').rglob('*.swift'))])
test_sources=phase('testSources','PBXSourcesBuildPhase',[ident('file:'+str(p.relative_to(root))) for p in sorted((root/'Tests'/'TelexTests').rglob('*.swift'))])
resource_phase=phase('appResources','PBXResourcesBuildPhase',resources)
app_frameworks=phase('appFrameworks','PBXFrameworksBuildPhase',[])
test_frameworks=phase('testFrameworks','PBXFrameworksBuildPhase',[])
def config_list(prefix,values):
    refs=[]
    for name in ['Debug','Release']:
        build=dict(values)
        build.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'})
        if name=='Debug': build.update({'ENABLE_TESTABILITY':'YES','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited) DEBUG'})
        refs.append(add(prefix+name,'XCBuildConfiguration',buildSettings=settings(build),name=quote(name)))
    return add(prefix+'List','XCConfigurationList',buildConfigurations=array(refs),defaultConfigurationIsVisible='0',defaultConfigurationName=quote('Release'))
common={'MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'6.0','SWIFT_STRICT_CONCURRENCY':'complete','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Manual','CODE_SIGN_IDENTITY':'-'}
project_configs=config_list('projectConfig',common)
app_configs=config_list('appConfig',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.telex.mac','INFOPLIST_FILE':'Config/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_ENTITLEMENTS':'Config/Telex.entitlements','ENABLE_HARDENED_RUNTIME':'YES','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks']})
test_configs=config_list('testConfig',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.telex.mac.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Telex.app/Contents/MacOS/Telex','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks','@loader_path/../Frameworks']})
app_target=add('appTarget','PBXNativeTarget',buildConfigurationList=app_configs,buildPhases=array([app_sources,app_frameworks,resource_phase]),buildRules='()',dependencies='()',name=quote('Telex'),productName=quote('Telex'),productReference=app_product,productType=quote('com.apple.product-type.application'))
proxy=add('testDependencyProxy','PBXContainerItemProxy',containerPortal=ident('project'),proxyType='1',remoteGlobalIDString=app_target,remoteInfo=quote('Telex'))
dependency=add('testDependency','PBXTargetDependency',target=app_target,targetProxy=proxy)
test_target=add('testTarget','PBXNativeTarget',buildConfigurationList=test_configs,buildPhases=array([test_sources,test_frameworks]),buildRules='()',dependencies=array([dependency]),name=quote('TelexTests'),productName=quote('TelexTests'),productReference=test_product,productType=quote('com.apple.product-type.bundle.unit-test'))
project=add('project','PBXProject',attributes='{ LastUpgradeCheck = 1600; BuildIndependentTargetsInParallel = YES; }',buildConfigurationList=project_configs,compatibilityVersion=quote('Xcode 14.0'),developmentRegion=quote('en'),hasScannedForEncodings='0',knownRegions=array([quote('en'),quote('Base')]),mainGroup=main_group,productRefGroup=products,projectDirPath=quote(''),projectRoot=quote(''),targets=array([app_target,test_target]))
content='// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
content+='\n'.join(key+' = '+value for key,value in objects.items())
content+='\n}; rootObject = '+project+'; }\n'
(root/'Telex.xcodeproj'/'project.pbxproj').write_text(content)
def ref(target,product): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{product.split(chr(46))[0]}" ReferencedContainer="container:Telex.xcodeproj"/>'
app_ref=ref(app_target,'Telex.app'); test_ref=ref(test_target,'TelexTests.xctest')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(root/'Telex.xcodeproj'/'xcshareddata'/'xcschemes'/'Telex.xcscheme').write_text(scheme)
print('Generated',root/'Telex.xcodeproj')
