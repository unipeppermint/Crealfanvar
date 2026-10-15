from pathlib import Path
p=Path('Crealfanvar.xcodeproj/project.pbxproj')
s=p.read_text()
if 'CFVUITests' not in s:
    additions='''
        CF0000000000000000000001 = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = CFVUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
        CF0000000000000000000002 = {isa = PBXFileSystemSynchronizedRootGroup; path = CrealfanvarUITests; sourceTree = "<group>"; };
        CF0000000000000000000003 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
        CF0000000000000000000004 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
        CF0000000000000000000005 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
        CF0000000000000000000006 = {isa = PBXContainerItemProxy; containerPortal = 04B4818A3080784400E294A0; proxyType = 1; remoteGlobalIDString = 04B481913080784400E294A0; remoteInfo = Crealfanvar; };
        CF0000000000000000000007 = {isa = PBXTargetDependency; target = 04B481913080784400E294A0; targetProxy = CF0000000000000000000006; };
        CF0000000000000000000008 = {isa = PBXNativeTarget; buildConfigurationList = CF0000000000000000000009; buildPhases = (CF0000000000000000000003, CF0000000000000000000004, CF0000000000000000000005); buildRules = (); dependencies = (CF0000000000000000000007); fileSystemSynchronizedGroups = (CF0000000000000000000002); name = CFVUITests; productName = CFVUITests; productReference = CF0000000000000000000001; productType = "com.apple.product-type.bundle.ui-testing"; };
        CF0000000000000000000009 = {isa = XCConfigurationList; buildConfigurations = (CF000000000000000000000A, CF000000000000000000000B); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
        CF000000000000000000000A = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 15.0; PRODUCT_BUNDLE_IDENTIFIER = com.tumopa.Crealfanvar.UITests; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = Crealfanvar; }; name = Debug; };
        CF000000000000000000000B = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 15.0; PRODUCT_BUNDLE_IDENTIFIER = com.tumopa.Crealfanvar.UITests; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = Crealfanvar; }; name = Release; };
'''
    s=s.replace('objects = {','objects = {'+additions,1)
    s=s.replace('04B481943080784400E294A0 /* Crealfanvar */,','04B481943080784400E294A0 /* Crealfanvar */,\n                CF0000000000000000000002,',1)
    s=s.replace('04B481923080784400E294A0 /* Crealfanvar.app */,','04B481923080784400E294A0 /* Crealfanvar.app */,\n                CF0000000000000000000001,',1)
    s=s.replace('04B481913080784400E294A0 /* Crealfanvar */,\n\t\t\t);','04B481913080784400E294A0 /* Crealfanvar */,\n                CF0000000000000000000008,\n\t\t\t);')
    p.write_text(s)
