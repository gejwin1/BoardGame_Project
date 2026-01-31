# Player Status Controller (GUID: [Need to verify])

## 📋 Overview
The `Player Status Controller` script (`PlayerStatusController.lua`) is a middleware/bridge controller that forwards status-related commands from the Event Engine to the Token Engine. It provides a unified API (`PS_Event`) for managing player status tokens (SICK, WOUNDED, ADDICTION, etc.), marriage tokens, and child tokens. The controller acts as an abstraction layer, mapping high-level symbolic keys to status tags and forwarding operations to the Token Engine via `object.call` wrappers. Version 0.3.0.

## 🚀 Functionality

### Primary Role
- **Middleware**: Bridges Event Engine and Token Engine
- **API Unification**: Provides single `PS_Event()` function for all status operations
- **Key Mapping**: Converts symbolic status keys (e.g., "SICK") to status tags (e.g., "WLB_STATUS_SICK")
- **Safe Forwarding**: Uses `safeCall()` to forward commands to Token Engine

### Supported Status Operations
1. **ADD_STATUS**: Add a status token to a player
2. **REMOVE_STATUS**: Remove a status token from a player
3. **CLEAR_STATUSES**: Remove all status tokens from a player
4. **REFRESH_STATUSES**: Refresh status token display for a player
5. **ADD_MARRIAGE**: Add a marriage token to a player
6. **ADD_CHILD**: Add a child token to a player (BOY, GIRL, or random)

### Status Tags Supported
- `WLB_STATUS_SICK`: Sickness status
- `WLB_STATUS_WOUNDED`: Wounded status
- `WLB_STATUS_ADDICTION`: Addiction status
- `WLB_STATUS_DATING`: Dating status
- `WLB_STATUS_GOOD_KARMA`: Good Karma status
- `WLB_STATUS_EXPERIENCE`: Experience status

### Symbolic Key Mapping
The controller maps symbolic keys to status tags:
- `SICK` → `WLB_STATUS_SICK`
- `WOUNDED` → `WLB_STATUS_WOUNDED`
- `ADDICTION` → `WLB_STATUS_ADDICTION`
- `DATING` → `WLB_STATUS_DATING`
- `GOODKARMA` → `WLB_STATUS_GOOD_KARMA`
- `EXPERIENCE` → `WLB_STATUS_EXPERIENCE`

## 🔗 External API

### Primary API Function: `PS_Event(payload)`

**Purpose**: Unified entry point for all status operations

**Payload Format**:
```lua
{
  color = "Yellow",           -- Player color (required for most ops)
  op = "ADD_STATUS",          -- Operation type (required)
  statusTag = "WLB_STATUS_SICK",  -- Direct status tag (optional)
  statusKey = "SICK",         -- Symbolic key (optional, alternative to statusTag)
  sex = "BOY"                 -- For ADD_CHILD: "BOY", "GIRL", or nil (random)
}
```

**Supported Operations**:
- `"ADD_STATUS"`: Add status token (requires `statusTag` or `statusKey`)
- `"REMOVE_STATUS"`: Remove status token (requires `statusTag` or `statusKey`)
- `"CLEAR_STATUSES"`: Remove all status tokens for player
- `"REFRESH_STATUSES"`: Refresh status display for player
- `"ADD_MARRIAGE"`: Add marriage token to player
- `"ADD_CHILD"`: Add child token (optional `sex="BOY"` or `"GIRL"`)
- `"PING"`: Test/debug function (no color required)

**Examples**:
```lua
-- Add SICK status using symbolic key
PS_Event({ color="Blue", op="ADD_STATUS", statusKey="SICK" })

-- Add SICK status using direct tag
PS_Event({ color="Blue", op="ADD_STATUS", statusTag="WLB_STATUS_SICK" })

-- Remove status
PS_Event({ color="Blue", op="REMOVE_STATUS", statusKey="SICK" })

-- Add child (random gender)
PS_Event({ color="Yellow", op="ADD_CHILD" })

-- Add child (specific gender)
PS_Event({ color="Yellow", op="ADD_CHILD", sex="BOY" })

-- Clear all statuses
PS_Event({ color="Red", op="CLEAR_STATUSES" })
```

**Return Value**: `true` on success, `false` on failure (errors logged to console)

## 🔗 Integration with Other Systems

### Token Engine (WLB_TOKEN_SYSTEM)
- **Relationship**: This controller forwards all commands to Token Engine
- **Method**: Uses `object.call()` to invoke Token Engine's `*_ARGS` wrapper functions:
  - `TE_AddStatus_ARGS`
  - `TE_RemoveStatus_ARGS`
  - `TE_ClearStatuses_ARGS`
  - `TE_RefreshStatuses_ARGS`
  - `TE_AddMarriage_ARGS`
  - `TE_AddChild_ARGS`
- **Requirement**: Token Engine must expose these `*_ARGS` wrapper functions

### Event Engine
- **Relationship**: Event Engine calls `PS_Event()` when events require status changes
- **Usage**: Event Engine sends symbolic keys or direct tags, controller handles conversion and forwarding

### Other Controllers
- **Shop Engine**: Uses `PS_Event()` for status management (e.g., removing SICK/WOUNDED after CURE card)
- **Any Controller**: Can call `PS_Event()` for status operations

## ⚙️ Configuration

### Tags
- `TAG_SELF`: `"WLB_PLAYER_STATUS_CTRL"` (Self-identification tag)
- `TAG_TOKEN_ENGINE`: `"WLB_TOKEN_SYSTEM"` (Tag for finding Token Engine)

### Status Tag Constants
All status tags must match Token Engine's constants:
- `TAG_STATUS_SICK`: `"WLB_STATUS_SICK"`
- `TAG_STATUS_WOUNDED`: `"WLB_STATUS_WOUNDED"`
- `TAG_STATUS_ADDICTION`: `"WLB_STATUS_ADDICTION"`
- `TAG_STATUS_DATING`: `"WLB_STATUS_DATING"`
- `TAG_STATUS_GOODKARMA`: `"WLB_STATUS_GOOD_KARMA"`
- `TAG_STATUS_EXPERIENCE`: `"WLB_STATUS_EXPERIENCE"`

### Key-to-Tag Mapping
Defined in `MAP_KEY_TO_TAG` table, maps symbolic keys (uppercase) to full status tag strings.

## 🎮 UI Elements

### Debug Buttons (on controller tile)
- **TEST +SICK (Y)**: Adds SICK status to Yellow player (test function)
- **TEST -SICK (Y)**: Removes SICK status from Yellow player (test function)

These buttons are for manual testing/debugging.

## 🔧 Technical Details

### Token Engine Resolution
- Searches for Token Engine by tag `WLB_TOKEN_SYSTEM` on load
- Caches Token Engine reference for subsequent calls
- Validates Token Engine presence before forwarding commands

### Safe Method Calls
- Uses `safeCall()` wrapper with `pcall()` for all Token Engine calls
- Handles errors gracefully, logs warnings on failure
- Returns boolean success/failure from `PS_Event()`

### Input Normalization
- **Colors**: Normalized to TitleCase ("Yellow", "Blue", etc.)
- **Keys/Operations**: Normalized to UPPERCASE
- **Sex/Gender**: Normalized to UPPERCASE ("BOY", "GIRL", or nil for random)

### Status Tag Resolution
The `resolveStatusTag()` function resolves status tags in priority order:
1. Explicit `statusTag` or `tag` field in payload
2. Symbolic `statusKey`, `effect`, or `status` field (mapped via `MAP_KEY_TO_TAG`)
3. Returns empty string if no valid tag/key found

## ⚠️ Notes

### Design Philosophy
- **Abstraction Layer**: Provides high-level API while delegating implementation to Token Engine
- **Flexibility**: Accepts both symbolic keys and direct tags for maximum compatibility
- **Error Handling**: Comprehensive error logging and graceful failure handling

### Dependencies
- **Token Engine**: Must be present and expose `*_ARGS` wrapper functions
- **Status Tags**: Must match Token Engine's tag constants exactly

### Limitations
- Only forwards operations to Token Engine; does not manage status tokens directly
- Requires Token Engine to implement the `*_ARGS` wrapper functions
- Debug buttons are hardcoded to Yellow player (for testing only)

### Usage Pattern
Typical flow:
1. Event Engine (or other controller) calls `PS_Event()` with symbolic key or tag
2. Controller resolves status tag from key (if needed)
3. Controller forwards command to Token Engine via `safeCall()`
4. Token Engine performs the actual status token manipulation
5. Controller returns success/failure status
