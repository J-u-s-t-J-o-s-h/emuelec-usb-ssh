@echo off
rem Creates the dedicated client key for the handheld (no passphrase). Never overwrites an existing key.
if exist "%USERPROFILE%\.ssh\emuelec_ed25519" (echo Key already exists: %USERPROFILE%\.ssh\emuelec_ed25519 & goto show)
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
ssh-keygen -q -t ed25519 -N "" -C %COMPUTERNAME%-emuelec -f "%USERPROFILE%\.ssh\emuelec_ed25519" < NUL
:show
type "%USERPROFILE%\.ssh\emuelec_ed25519.pub"
