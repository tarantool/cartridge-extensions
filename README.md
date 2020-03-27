## Cartridge-extensions

This module represents new role `extensions` for cartridge.

All `extensions/*.lua` files will be loaded as Lua modules.
They'll be accessible through

```lua
local banking = require('extensions.banking')
```

Also `extensions/config.yml` describes how to export those modules in
serverless style. For now we'll support the only event `binary`:

```yml
functions:
  transfer_money:
    module: banking
    handler: transfer_money
    events:
    - binary:
      # It'll assign _G.__transfer_money = banking.transfer_money
        path: __transfer_money
```
