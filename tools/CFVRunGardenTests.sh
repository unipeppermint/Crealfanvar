#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swiftc -module-cache-path /tmp/CFVSwiftModuleCache \
    Crealfanvar/Services/CFVGardenStore.swift \
    CrealfanvarTests/CFVGardenTests.swift \
    -o /tmp/CFVGardenTests
/tmp/CFVGardenTests
