@echo off
echo Setting up Android build environment...
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
echo JAVA_HOME set to: %JAVA_HOME%
echo.
echo You can now run Android build commands from the android directory:
echo   cd android
echo   gradlew build
echo.
echo Or use Flutter commands from the root directory:
echo   flutter build apk
echo   flutter run
