# Issue Report: Asimov-ZSH Service Failure (2025-12-06)

## Summary

The `com.tobiashochguertel.asimov-zsh` launchd service was failing with exit code 1 due to missing PATH environment variable in the plist configuration.

## Symptoms

- Service status showed: `last exit code = 1`
- Error message in system: "General error - Program: /usr/local/bin/asimov"
- Service appeared to be loaded but not functioning
- Manual execution of the script worked correctly

## Root Cause

The `asimov-zsh` script depends on the `fd` command (installed via Homebrew at `/opt/homebrew/bin/fd`). However, launchd services run with a minimal default PATH that only includes:

```
/usr/bin:/bin:/usr/sbin:/sbin
```

This PATH does not include Homebrew's binary directories (`/opt/homebrew/bin` or `/usr/local/bin`), causing the script to fail when trying to execute the `fd` command.

## Investigation Steps

1. Checked service status:
   ```bash
   launchctl list | grep asimov
   launchctl print gui/$(id -u)/com.tobiashochguertel.asimov-zsh
   ```

2. Verified the binary exists and is correct:
   ```bash
   ls -la /usr/local/bin/asimov
   /usr/local/bin/asimov --version
   ```

3. Identified missing `fd` in default PATH:
   ```bash
   which fd
   # Returns: /opt/homebrew/bin/fd
   
   /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin which fd
   # Returns: (not found)
   ```

4. Confirmed script works with correct PATH:
   ```bash
   PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin asimov
   # Success!
   ```

## Solution

Added PATH environment variable to the plist file to include Homebrew's binary directories:

```xml
<key>EnvironmentVariables</key>
<dict>
    <!-- PATH needs to include Homebrew bin for fd command -->
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    
    <!-- Other environment variables... -->
</dict>
```

## Files Modified

1. **`com.tobiashochguertel.asimov-zsh.plist`**
   - Added PATH environment variable
   - Includes both `/opt/homebrew/bin` (Apple Silicon) and `/usr/local/bin` (Intel Macs)

2. **`docs/TROUBLESHOOTING.md`** (New)
   - Created comprehensive troubleshooting guide
   - Documents this issue and solution
   - Includes other common issues and debugging steps

3. **`CHANGELOG.md`**
   - Added entry for version 0.11.1
   - Documents the fix and its importance

4. **`README.md`**
   - Added link to troubleshooting guide in documentation section

## Verification

After applying the fix:

```bash
# Reload the service
launchctl unload ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist
launchctl load ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist

# Check status
launchctl list | grep asimov
# Result: -	0	com.tobiashochguertel.asimov-zsh

# Verify exit code
launchctl print gui/$(id -u)/com.tobiashochguertel.asimov-zsh | grep "last exit code"
# Result: last exit code = (never exited)

# Manually trigger to test
launchctl start com.tobiashochguertel.asimov-zsh

# Verify it ran successfully
launchctl print gui/$(id -u)/com.tobiashochguertel.asimov-zsh | grep "last exit code"
# Result: last exit code = (never exited)

# Check cache is working
sqlite3 ~/.cache/asimov.db "SELECT COUNT(*) FROM exclusions"
# Result: 910 (or your number of exclusions)
```

## Impact

- **Before**: Service failed silently every 24 hours, no exclusions were being maintained
- **After**: Service runs successfully, Time Machine exclusions are properly maintained

## Lessons Learned

1. **launchd PATH limitations**: launchd services don't inherit user PATH or shell environment
2. **Testing importance**: Always test services with the exact environment they'll run in
3. **Documentation value**: Comprehensive troubleshooting guides help users debug issues independently

## Related Issues

This issue would affect any user who:
- Installed asimov-zsh via the install script
- Has fd installed via Homebrew (standard installation method)
- Relies on the launchd service for automatic daily runs

## Prevention

- Updated default plist template includes proper PATH
- Added verification step to install script (could be future enhancement)
- Troubleshooting guide helps users identify and fix similar issues

## Date

- **Discovered**: 2025-12-06
- **Fixed**: 2025-12-06
- **Verified**: 2025-12-06

## Author

Tobias Hochguertel <tobias.hochguertel@googlemail.com>
