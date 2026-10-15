#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swiftc -module-cache-path /tmp/CFVSwiftModuleCache \
    Crealfanvar/GameCore/CFVGameCore.swift \
    Crealfanvar/Services/CFVRepository.swift \
    Crealfanvar/Services/CFVSaveStore.swift \
    CrealfanvarTests/CFVCoreTests.swift \
    -o /tmp/CFVCoreTests
/tmp/CFVCoreTests
