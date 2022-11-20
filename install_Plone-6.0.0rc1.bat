REM run the following in a Windows Command Processor (aka command shell)
REM install_Plone-6.0.0rc1.bat

SET TIMESTAMP_START=%date% %time%

REM store current path
SET OLD_PATH=%PATH%
REM clear path and use only actually needed paths
SET PATH=
SET PATH=%PATH%;C:\Windows
SET PATH=%PATH%;C:\Windows\system32
@ECHO %PATH%

REM set variables
SET PLONE_VERSION=6.0.0rc1
SET PLONE_HOME=s:\Plone_%PLONE_VERSION%_windows
SET PLONE_CONSTRAINTS_URL=https://dist.plone.org/release/%PLONE_VERSION%/constraints.txt
SET PLONE_REQUIREMENTS_URL=https://dist.plone.org/release/%PLONE_VERSION%/requirements.txt

SET PLONE_SITE_NAME=Plone
SET ZEO_HOST=127.0.0.1
SET ZEO_PORT=8100
SET ZOPE_INSTANCE_NAME=client1
REM set localhost instead of 127.0.0.1
REM see https://community.plone.org/t/http-127-0-0-1-8080-plone-and-http-localhost-8080-plone-render-differently/15257
REM see https://pypi.org/project/plone.app.theming/#advanced-settings
SET ZOPE_INSTANCE_HOST=localhost
SET ZOPE_INSTANCE_PORT=8081
cd /d %HOMEDRIVE%%HOMEPATH%

REM delete PLONE_HOME directory if it exists
if exist "%PLONE_HOME%" rmdir /q /s "%PLONE_HOME%"

REM create directory PLONE_HOME
mkdir "%PLONE_HOME%"
cd /d "%PLONE_HOME%"

REM create venv in PLONE_HOME
REM C:\Python39\python.exe -m venv "%PLONE_HOME%"
SET PYTHON_TARGET_DIR=c:\Python39
"%PYTHON_TARGET_DIR%\python.exe" -m venv "%PLONE_HOME%"

REM get installed versions
"%PLONE_HOME%\Scripts\python.exe" --version
"%PLONE_HOME%\Scripts\pip.exe" --version


curl -s %PLONE_CONSTRAINTS_URL% > constraints.txt
REM we don't need plone.volto for Classic UI Site
curl -s %PLONE_CONSTRAINTS_URL% | findstr /v plone.volto > constraints.txt
REM if yes, uncomment the following line
REM curl -s %PLONE_CONSTRAINTS_URL% > constraints.txt
SET PLONE_CONSTRAINTS=%PLONE_HOME%\constraints.txt

REM installing via "requirements.txt" will mess up pip
REM we manually modify pip version
"%PLONE_HOME%\Scripts\python.exe" -m pip install -U pip==22.3.1 -c %PLONE_CONSTRAINTS%
REM install setuptools wheel for PLONE_VERSION
"%PLONE_HOME%\Scripts\pip.exe" install setuptools==65.5.1 -c %PLONE_CONSTRAINTS%
"%PLONE_HOME%\Scripts\pip.exe" install wheel==0.38.4 -c %PLONE_CONSTRAINTS%
REM we don't need zc.buildout for a pip installation
REM if yes, uncomment the following line
REM "%PLONE_HOME%\Scripts\pip.exe" install zc.buildout==3.0.1 -c %PLONE_CONSTRAINTS%

REM install Plone
"%PLONE_HOME%\Scripts\pip.exe" --debug install Plone -c %PLONE_CONSTRAINTS%

REM install zope.mkzeoinstance and cookiecutter
"%PLONE_HOME%\Scripts\pip.exe" install zope.mkzeoinstance==4.1 -c %PLONE_CONSTRAINTS%
"%PLONE_HOME%\Scripts\pip.exe" install cookiecutter==2.1.1 -c %PLONE_CONSTRAINTS%

REM create parts directory for zeo and zope instances
cd /d "%PLONE_HOME%
if exist "%PLONE_HOME%\parts" rmdir /q /s "%PLONE_HOME%\parts"

REM mkzeoinstance
"%PLONE_HOME%\Scripts\mkzeoinstance.exe" "%PLONE_HOME%\parts\zeoserver" %ZEO_HOST%:%ZEO_PORT%

REM generate zope-instance
cd /d "%PLONE_HOME%\parts"

> "%PLONE_HOME%\%ZOPE_INSTANCE_NAME%.yaml" (
@echo.default_context:
@echo.    target: '%ZOPE_INSTANCE_NAME%'
@echo.    wsgi_listen: '%ZOPE_INSTANCE_HOST%:%ZOPE_INSTANCE_PORT%'
@echo.    initial_user_name: 'admin'
@echo.    initial_user_password: 'admin'
@echo.    db_storage: 'zeo'
@echo.    db_zeo_server: '%ZEO_HOST%:%ZEO_PORT%'
@echo.    #db_filestorage_location: "filestorage/Data.fs"
@echo.    db_blobs_location: "blobstorage"
)
type "%PLONE_HOME%\%ZOPE_INSTANCE_NAME%.yaml"

REM temporary add git to path
SET PREVIOUS_PATH=%PATH%
SET PATH=%PATH%;C:\Program Files\Git\cmd
REM uncomement the following line when the pull request has been accepted. Replace the checkout version.
REM "%PLONE_HOME%\Scripts\cookiecutter" -f --no-input --config-file "%PLONE_HOME%\%ZOPE_INSTANCE_NAME%.yaml" --checkout 1.0.0b3  https://github.com/plone/cookiecutter-zope-instance
REM comement out the following line when the pull request has been accepted.
"%PLONE_HOME%\Scripts\cookiecutter" -f --no-input --config-file "%PLONE_HOME%\%ZOPE_INSTANCE_NAME%.yaml" https://github.com/me-kell/cookiecutter-zope-instance
REM this script won't need git anymore
SET PATH=%PREVIOUS_PATH%

REM runzeo in another window
SET RUNZEO_CMD=%PLONE_HOME%\Scripts\runzeo.exe -C %PLONE_HOME%\parts\zeoserver\etc\zeo.conf
@ECHO Runing "%RUNZEO_CMD%" in new terminal
start "runzeo" cmd.exe /C "echo %RUNZEO_CMD% & echo Press Ctrl-C to stop & %RUNZEO_CMD%"

REM runwsgi in another window
SET RUNWSGI_CMD=%PLONE_HOME%\Scripts\runwsgi -dv %PLONE_HOME%\parts\%ZOPE_INSTANCE_NAME%\etc\zope.ini
@ECHO Runing "%RUNWSGI_CMD%" in new terminal
start "runwsgi" cmd.exe /C "echo %RUNWSGI_CMD% & echo Press Ctrl-C to stop & %RUNWSGI_CMD%"

REM create a Python script to add a PloneSite
SET SCRIPTNAME=%PLONE_HOME%\create_plone_site.py
> "%SCRIPTNAME%" (
@echo.app._p_jar.sync(^)
@echo.from Testing.makerequest import makerequest
@echo.app = makerequest^(app^)
@echo.from AccessControl.SecurityManagement import newSecurityManager, noSecurityManager
@echo.admin_username='admin'
@echo.acl_users = app.acl_users
@echo.user = acl_users.getUser^(admin_username^)
@echo.user = user.__of__^(acl_users^)
@echo.newSecurityManager^(None,user^)
@echo.from Products.CMFPlone.factory import addPloneSite
@echo.plone_site_name = '%PLONE_SITE_NAME%'
@echo.plone_site_title = plone_site_name
@echo.if app.hasObject^(plone_site_name^): app.manage_delObjects^(plone_site_name^); print^(f"Deleted existing '{plone_site_name}'"^)
@echo.plone_site = addPloneSite^(app, plone_site_name, title=plone_site_title, description='', extension_ids=^('plonetheme.barceloneta:default', 'plone.app.caching:default'^), setup_content=True, default_language='en', portal_timezone='Europe/Berlin'^)
@echo.import transaction
@echo.transaction.commit^(^)
@echo.print^(f"Created '{plone_site}'"^)
)
type "%SCRIPTNAME%"

SET ZOPECONF_FILENAME=%PLONE_HOME%\parts\%ZOPE_INSTANCE_NAME%\etc\zope.conf
set "ZOPECONF_FILENAME_WITH_FORWARD_SLASHES=%ZOPECONF_FILENAME%"
set "ZOPECONF_FILENAME_WITH_FORWARD_SLASHES=%ZOPECONF_FILENAME_WITH_FORWARD_SLASHES:\=/%"

@ECHO ON

REM wait for runwsgi to start and run the script in zconsole
ping -n 30 %ZOPE_INSTANCE_HOST% >NUL && echo "running %SCRIPTNAME%" && call %PLONE_HOME%\Scripts\zconsole.exe run %ZOPECONF_FILENAME_WITH_FORWARD_SLASHES% "%SCRIPTNAME%"
REM wait and check if the PloneSite is available
ping -n 5 %ZOPE_INSTANCE_HOST% >NUL && curl -s "http://%ZOPE_INSTANCE_HOST%:%ZOPE_INSTANCE_PORT%/Plone" | findstr /R /C:"<title>%PLONE_SITE_NAME%</title>"

SET PATH=%OLD_PATH%

SET TIMESTAMP_END=%date% %time%
@ECHO TIMESTAMP_START = %TIMESTAMP_START%
@ECHO TIMESTAMP_END   = %TIMESTAMP_END%
