---
name: fix-guild-leave-bug
description: Fix the guild leave/rejoin bug in TimeSpace Girl server — applies 4 code fixes to GuildLogic.java
---

# Fix Guild Leave/Join Bug Skill

## Purpose
Automatically find and fix the "guild master leaves guild, then gets kicked from any new guild" bug in the TimeSpace Girl game server. Applies 4 code fixes to `GuildLogic.java` in the server source tree.

## Bug Summary
When a guild master transfers chairmanship and leaves their guild, they experience being unable to join any new guild — they either get rejected or immediately kicked out after joining.

### Root Causes Found:
1. **chairmanChange()**: target user added as CHAIRMAN without first being removed from old position → double membership, corrupted data
2. **applyToJoin() / createFamily()**: `leaveGuildTime` not cleared after successfully joining/creating a new guild → stale CD timestamp
3. **releaseGuild()**: unconditionally calls `setGuildId(0)` on ALL members during guild dissolution, even those who already joined a new guild

## Source File Location
The file to fix is `GuildLogic.java` under the server source. Search for it first — typical paths:
- `Server_x1tag1.2.2/server_game/serverlogic/src/main/java/com/ljsd/jieling/logic/family/GuildLogic.java`
- Or any path matching `**/serverlogic/**/logic/family/GuildLogic.java`

## Fixes to Apply

### Fix 1: chairmanChange — add removeMember before promoting target
Search for:
```java
        guildInfo.addMembers(GlobalsDef.CHAIRMAN, targetUid);
```
Replace with:
```java
        // [FIX] 转让会长前，先将目标用户从其旧职位中移除，避免成员同时存在于两个职位中导致数据损坏
        int targetType = getMemberType(targetUid, guildInfo.getMembers());
        guildInfo.removeMember(targetType, targetUid);
        guildInfo.addMembers(GlobalsDef.CHAIRMAN, targetUid);
```
(Note: `guildInfo.addMembers(GlobalsDef.CHAIRMAN, targetUid);` appears exactly ONCE in the file — inside `chairmanChange`)

### Fix 2a: applyToJoin — clear leaveGuildTime after joining
Search for (inside `applyToJoin` method, around line 754):
```java
            targetUser.getPlayerInfoManager().setGuildId(guildInfo.getId());
```
Replace with:
```java
            targetUser.getPlayerInfoManager().setGuildId(guildInfo.getId());
            // [FIX] 加入新公会后清除退出冷却时间，避免残留的leaveGuildTime导致后续问题
            targetUser.getPlayerInfoManager().setLeaveGuildTime(0);
```
(Note: `TargetUser.getPlayerInfoManager().setGuildId(guildInfo.getId())` — the indented version appears only in `applyToJoin`)

### Fix 2b: createFamily — clear leaveGuildTime after creating
Search for (inside `createFamily` method, around line 312):
```java
        user.getPlayerInfoManager().setGuildId(guildInfo.getId());
```
Replace with:
```java
        user.getPlayerInfoManager().setGuildId(guildInfo.getId());
        // [FIX] 创建公会后清除退出冷却时间
        user.getPlayerInfoManager().setLeaveGuildTime(0);
```
(Note: `User.getPlayerInfoManager().setGuildId(guildInfo.getId())` — the non-indented version appears exactly once, in `createFamily`)

### Fix 3: releaseGuild — only setGuildId(0) if member still in THIS guild
Search for:
```java
                User user = UserManager.getUser(sendUid);
                //TODO lock check
                OnUserLeveFamily(user);
                user.getPlayerInfoManager().setGuildId(0);
```
Replace with:
```java
                User user = UserManager.getUser(sendUid);
                //TODO lock check
                // [FIX] 仅当成员仍在此公会中时才清除guildId，避免误踢已加入其他公会的玩家
                if (user.getPlayerInfoManager().getGuildId() == guildInfo.getId()) {
                    OnUserLeveFamily(user);
                    user.getPlayerInfoManager().setGuildId(0);
                }
```

## Execution Steps

1. **Find the file**: Search for `GuildLogic.java` under the server source tree with `find` or `glob`
2. **Verify uniqueness**: Before each edit, verify the search string appears exactly once. If it appears 0 times or multiple times, STOP and ask
3. **Apply edits**: Use Python to read → replace → write to `/tmp/GuildLogic_fixed.java`
4. **Verify**: grep each [FIX] comment to confirm all 4 applied
5. **Handle permissions**: The source is likely in `~/Downloads/` or external to workspace. macOS will block writes. Write to `/tmp/` and give the user the `cp` command
6. **Give cp command**: Clear one-liner for the user to paste in terminal

## Verification Commands (after applying)
```bash
grep -c '转让会长前' /tmp/GuildLogic_fixed.java       # should output: 1
grep -c '加入新公会后清除' /tmp/GuildLogic_fixed.java  # should output: 1
grep -c '创建公会后清除' /tmp/GuildLogic_fixed.java    # should output: 1
grep -c '仅当成员仍在此公会' /tmp/GuildLogic_fixed.java # should output: 1
```

## Post-Fix
After the user copies the file, remind them to rebuild the server JAR:
```bash
cd server_game && ./gradlew build
```
