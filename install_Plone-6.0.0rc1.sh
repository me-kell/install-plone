: ;# run the following in a Windows Command Processor (aka command shell)
: ;# install_plone.sh

TSTAMP_START=$(date +%Y.%m.%d-%H.%M.%S)

sudo apt-get install -y python3-venv
sudo apt-get install -y git
sudo apt-get install -y curl

: ;# store current path
OLD_PATH=${PATH}

# clear path and use only actually needed paths
PATH=
PATH=${PATH}:/usr/local/bin
PATH=${PATH}:/usr/bin
PATH=${PATH}:/bin

echo ${PATH}

: ;# set variables
PLONE_VERSION=6.0.0rc1
PLONE_HOME=${HOME}/Plone_${PLONE_VERSION}_debian
PLONE_CONSTRAINTS_URL=https://dist.plone.org/release/${PLONE_VERSION}/constraints.txt
PLONE_REQUIREMENTS_URL=https://dist.plone.org/release/${PLONE_VERSION}/requirements.txt

PLONE_SITE_NAME=Plone
ZEO_HOST=127.0.0.1
ZEO_PORT=8100
ZOPE_INSTANCE_NAME=client1
: ;# set localhost instead of 127.0.0.1
: ;# see https://community.plone.org/t/http-127-0-0-1-8080-plone-and-http-localhost-8080-plone-render-differently/15257
: ;# see https://pypi.org/project/plone.app.theming/#advanced-settings
ZOPE_INSTANCE_HOST=192.168.45.129
ZOPE_INSTANCE_PORT=8081
cd ${HOME}

: ;# delete PLONE_HOME directory if it exists
rm -rf ${PLONE_HOME}

: ;# create directory PLONE_HOME
mkdir -p "${PLONE_HOME}"
cd "${PLONE_HOME}"

: ;# create venv in PLONE_HOME
PYTHON_TARGET_DIR=/usr/bin
${PYTHON_TARGET_DIR}/python3 -m venv "${PLONE_HOME}"

: ;# get installed versions
${PLONE_HOME}/bin/python --version
${PLONE_HOME}/bin/pip --version

: ;# we don't need plone.volto for Classic UI Site
curl -s ${PLONE_CONSTRAINTS_URL} | grep -v plone.volto > constraints.txt
: ;# if yes, uncomment the following line
: ;# curl -s ${PLONE_CONSTRAINTS_URL} > constraints.txt
PLONE_CONSTRAINTS=${PLONE_HOME}/constraints.txt

: ;# installing via "requirements.txt" will mess up pip
: ;# we manually modify pip version
${PLONE_HOME}/bin/python -m pip install -U pip==22.3.1 -c ${PLONE_CONSTRAINTS}
: ;# install setuptools wheel for PLONE_VERSION
${PLONE_HOME}/bin/pip install setuptools==65.5.1 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install wheel==0.38.4 -c ${PLONE_CONSTRAINTS}
: ;# we don't need zc.buildout for a pip installation
: ;# if yes, uncomment the following line
: ;# ${PLONE_HOME}/bin/pip install zc.buildout==3.0.1 -c ${PLONE_CONSTRAINTS}

: ;# install Plone
: ;# we don't need plone.volto for a Clasic UUI installation
: ;# if yes, uncomment the following line
: ;# ${PLONE_HOME}/bin/pip --debug install Plone -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install plone.app.caching==3.0.0 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install plone.app.iterate==4.0.3 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install plone.app.upgrade==3.0.0rc1 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install plone.restapi==8.32.2 -c ${PLONE_CONSTRAINTS}
: ;# ${PLONE_HOME}/bin/pip install plone.volto==4.0.0 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install Products.CMFPlacefulWorkflow==3.0.0b2 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install Products.CMFPlone==6.0.0rc1 -c ${PLONE_CONSTRAINTS}

: ;# install zope.mkzeoinstance and cookiecutter
${PLONE_HOME}/bin/pip install zope.mkzeoinstance==4.1 -c ${PLONE_CONSTRAINTS}
${PLONE_HOME}/bin/pip install cookiecutter==2.1.1 -c ${PLONE_CONSTRAINTS}

: ;# create parts directory for zeo and zope instances
cd ${PLONE_HOME}
rm -rf ${PLONE_HOME}/parts

: ;# mkzeoinstance
${PLONE_HOME}/bin/mkzeoinstance ${PLONE_HOME}/parts/zeoserver ${ZEO_HOST}:${ZEO_PORT}

: ;# generate zope-instance
cd ${PLONE_HOME}/parts

cat <<EOF | tee ${PLONE_HOME}/${ZOPE_INSTANCE_NAME}.yaml
default_context:
    target: '${ZOPE_INSTANCE_NAME}'
    wsgi_listen: '${ZOPE_INSTANCE_HOST}:${ZOPE_INSTANCE_PORT}'
    initial_user_name: 'admin'
    initial_user_password: 'admin'
    db_storage: 'zeo'
    db_zeo_server: '${ZEO_HOST}:${ZEO_PORT}'
    #db_filestorage_location: "filestorage/Data.fs"
    db_blobs_location: "blobstorage"
EOF
cat ${PLONE_HOME}/${ZOPE_INSTANCE_NAME}.yaml

: ;# uncomement the following line when the pull request has been accepted. Replace the checkout version.
: ;# ${PLONE_HOME}/bin/cookiecutter -f --no-input --config-file "${PLONE_HOME}/${ZOPE_INSTANCE_NAME}.yaml" --checkout 1.0.0b3  https://github.com/plone/cookiecutter-zope-instance
: ;# comment out the following line when the pull request has been accepted.
${PLONE_HOME}/bin/cookiecutter -f --no-input --config-file "${PLONE_HOME}/${ZOPE_INSTANCE_NAME}.yaml" https://github.com/me-kell/cookiecutter-zope-instance

: ;# runzeo in another window
RUNZEO_CMD="${PLONE_HOME}/bin/runzeo -C ${PLONE_HOME}/parts/zeoserver/etc/zeo.conf"
echo "Runing \"${RUNZEO_CMD}\" as background job"
echo "\"${RUNZEO_CMD}\"" && echo "Enter 'fg' and Press Ctrl-C to stop" && ${RUNZEO_CMD} &

: ;# runwsgi in another window
RUNWSGI_CMD="${PLONE_HOME}/bin/runwsgi -dv ${PLONE_HOME}/parts/${ZOPE_INSTANCE_NAME}/etc/zope.ini"
echo "Runing \"${RUNWSGI_CMD}\" as background job"
echo "\"${RUNWSGI_CMD}\"" && echo "Enter 'fg' and Press Ctrl-C to stop" && ${RUNWSGI_CMD} &

: ;# create a Python script to add a PloneSite
SCRIPTNAME=${PLONE_HOME}/create_plone_site.py
cat <<EOF | tee ${SCRIPTNAME}
app._p_jar.sync()
from Testing.makerequest import makerequest
app = makerequest(app)
from AccessControl.SecurityManagement import newSecurityManager, noSecurityManager
admin_username='admin'
acl_users = app.acl_users
user = acl_users.getUser(admin_username)
user = user.__of__(acl_users)
newSecurityManager(None,user)
from Products.CMFPlone.factory import addPloneSite
plone_site_name = '${PLONE_SITE_NAME}'
plone_site_title = plone_site_name
if app.hasObject(plone_site_name): app.manage_delObjects(plone_site_name); print(f"Deleted existing '{plone_site_name}'")
plone_site = addPloneSite(app, plone_site_name, title=plone_site_title, description='', extension_ids=('plonetheme.barceloneta:default', 'plone.app.caching:default'), setup_content=True, default_language='en', portal_timezone='Europe/Berlin')
import transaction
transaction.commit()
print(f"Created '{plone_site}'")
EOF
cat ${SCRIPTNAME}

: ;# set a variable for the file zope.conf
ZOPECONF_FILENAME_WITH_FORWARD_SLASHES=${PLONE_HOME}/parts/${ZOPE_INSTANCE_NAME}/etc/zope.conf

: ;# wait for runwsgi to start and run the script in zconsole
sleep 30 && echo "Waiting 30 sec. before running \"${SCRIPTNAME}\"" && ${PLONE_HOME}/bin/zconsole run ${ZOPECONF_FILENAME_WITH_FORWARD_SLASHES} "${SCRIPTNAME}"

: ;# wait and check if the PloneSite is available
sleep 5 && echo "Waiting 5 sec. before requesting Plone" && curl -s "http://${ZOPE_INSTANCE_HOST}:${ZOPE_INSTANCE_PORT}/Plone" | grep "<title>${PLONE_SITE_NAME}</title>"

echo "Enter 'jobs && kill \$(jobs -p)' to kill all background jobs."

PATH=${OLD_PATH}

TSTAMP_END=$(date +%Y.%m.%d-%H.%M.%S)
echo -E "TSTAMP_START = ${TSTAMP_START}"
echo -E "TSTAMP_END   = ${TSTAMP_END}"
