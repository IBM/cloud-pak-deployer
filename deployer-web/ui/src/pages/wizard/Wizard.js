import React from 'react';
import OpenShiftLogin from './OpenShiftLogin/OpenShiftLogin';
import Selection from './Selection/Selection';
import './Wizard.scss'
import { useState, useEffect } from 'react';
import { ProgressIndicator, ProgressStep, Button, InlineNotification, Loading } from '@carbon/react';
import Summary from './Summary/Summary';
import axios from 'axios';
import CloudPak from './CloudPak/CloudPak';
import { useNavigate } from 'react-router-dom';

const Wizard = ({ setHeaderTitle,
  headerTitle
}) => {
  const navigate = useNavigate();

  //wizard index
  const [currentIndex, setCurrentIndex] = useState(0);
  const [wizardError, setWizardError] = useState(false);
  const [ocLoginErr, setOcLoginErr] = useState(false)
  const [checkDeployerStatusErr, setCheckDeployerStatusErr] = useState(false)

  //Environment variables loading
  const [loadingEnviromentVariables, setLoadingEnviromentVariables] = useState(false)
  const [loadEnviromentVariablesErr, setloadEnviromentVariablesErr] = useState(false)

  //Deploy loading
  const [loadingDeployStatus, setLoadingDeployStatus] = useState(false)

  //Selection
  const [selection, setSelection] = useState('Configure+Deploy')
  const [cpdWizardMode, setCpdWizardMode] = useState('')

  //OpenShift Login
  const [cloudPlatform, setCloudPlatform] = useState("existing-ocp")
  const [configuration, setConfiguration] = useState({})
  const [envId, setEnvId] = useState("")
  //---Existing OpenShift
  const [OCPSettings, setOCPSettings] = useState({
    ocLoginCmd: '',
  })
  const [isOcLoginCmdInvalid, setOcLoginCmdInvalid] = useState(false)

  //Cloud Pak
  const [CPDCartridgesData, setCPDCartridgesData] = useState([])
  const [CPICartridgesData, setCPICartridgesData] = useState([])
  const [entitlementKey, setEntitlementKey] = useState('')
  const [adminPassword, setAdminPassword] = useState('')
  const [cp4dLicense, setCp4dLicense] = useState(false)
  const [cp4iLicense, setCp4iLicense] = useState(false)
  const [cp4dVersion, setCp4dVersion] = useState('')
  const [cp4iVersion, setCp4iVersion] = useState('')

  //summary
  const [summaryLoading, setSummaryLoading] = useState(false)
  const [tempSummaryInfo, setTempSummaryInfo] = useState("")
  const [configInvalid, setConfigInvalid] = useState(false)
  const [showErr, setShowErr] = useState(false)
  const [configDir, setConfigDir] = useState('')
  const [statusDir, setStatusDir] = useState('')
  const [saveConfig, setSaveConfig] = useState(false)
  const [deployerContext, setDeployerContext] = useState('local')

  //For Private Registry  
  const [registryHostname, setRegistryHostname] = useState('')
  const [registryPort, setRegistryPort] = useState(443)
  const [registryNS, setRegistryNS] = useState('')
  const [registryUser, setRegistryUser] = useState('')
  const [registryPassword, setRegistryPassword] = useState('')
  const [portable, setPortable] = useState(false)

  const clickPrevious = () => {
    setWizardError(false)
    if (currentIndex >= 1)
      setCurrentIndex(currentIndex - 1)
  }

  const clickNext = async () => {
    console.log(currentIndex, deployerContext, selection)
    if (currentIndex === 0 && deployerContext === "openshift" && selection !== "Configure+Download") {
      let result = await checkOpenShiftConnected();
      // If already logged into OpenShift, skip oc login
      if (result === 1) {
        setCurrentIndex(2)
        let deployerStatus = await checkDeployerStatus();
        if (deployerStatus === 1) {
          setCheckDeployerStatusErr(false)
          navigate('/status')
          return
        }
        if (deployerStatus === -1) {
          setCheckDeployerStatusErr(true)
          return
        }
        return
      }
    }

    if (currentIndex === 0 && deployerContext === "local" && selection === "Configure") {
      setCurrentIndex(2)
      return
    }

    if (currentIndex === 1 && selection !== "Configure+Download") {
      setLoadingDeployStatus(true)
      let result = await testOcLoginCmd();

      //test OC Login Cmd failure
      if (result !== 0) {
        return
      } else {
        let deployerStatus = await checkDeployerStatus();
        if (deployerStatus === 1) {
          setCheckDeployerStatusErr(false)
          navigate('/status')
          return
        }
        if (deployerStatus === -1) {
          setCheckDeployerStatusErr(true)
          return
        }
      }
    }
    setWizardError(true)
    if (currentIndex <= 3)
      setCurrentIndex(currentIndex + 1)
  }

  const checkDeployerStatus = async () => {
    let result = 0;
    await axios.get('/api/v1/deployer-status').then(res => {
      if (res.data.deployer_active === true) {
        result = 1;
      }
    }, err => {
      console.log(err)
      result = -1;
    });
    return result
  }

  const checkOpenShiftConnected = async () => {
    let result = 0;
    await axios.get('/api/v1/oc-check-connection').then(res => {

      if (res.data.connected === true) {
        result = 1;
      }
    }, err => {
      console.log(err)
      result = -1;
    });
    return result
  }

  const testOcLoginCmd = async () => {
    let patt = /oc\s+login\s+/;
    if (!patt.test(OCPSettings.ocLoginCmd.trim())) {
      setOcLoginCmdInvalid(true)
      setLoadingDeployStatus(false)
      return
    }
    setOcLoginCmdInvalid(false)
    const body = {
      "oc_login_command": OCPSettings.ocLoginCmd
    }
    let result = -1
    await axios.post('/api/v1/oc-login', body).then(res => {
      result = res.data.code
      if (result !== 0) {
        setOcLoginErr(true)
      } else {
        setOcLoginErr(false)
      }
    }, err => {
      setOcLoginErr(true)
    }
    );
    setLoadingDeployStatus(false)
    return result;
  }

  const createDeployment = async () => {
    setLoadingDeployStatus(true)
    const body = {
      "env": {},
      "entitlementKey": entitlementKey,
      "cloud": cloudPlatform,
      "envId": envId,
      "oc_login_command": OCPSettings.ocLoginCmd.trim(),
      "adminPassword": adminPassword,
    }
    
    await axios.post('/api/v1/deploy', body).then(res => {
      setLoadingDeployStatus(false)
      navigate('/status')
    }, err => {
      setLoadingDeployStatus(false)
      console.log(err)
      alert('Error starting deployment: ' + (err.response?.data?.message || err.message))
    });
  }

  const createDownload = async () => {
    setLoadingDeployStatus(true)
    const body = {
      "entitlementKey": entitlementKey,
      "envId": envId,
      "registry": {
        "portable": portable,
        "registryHostname": registryHostname,
        "registryPort": registryPort,
        "registryNS": registryNS,
        "registryUser": registryUser,
        "registryPassword": registryPassword,
      }
    }
    await axios.post('/api/v1/mirror', body).then(res => {
      setLoadingDeployStatus(false)
      navigate('/status')
    }, err => {
      setLoadingDeployStatus(false)
      console.log(err)
      alert('Error starting download: ' + (err.response?.data?.message || err.message))
    });
  }

  const saveConfiguration = async () => {
    setLoadingDeployStatus(true)
    let result = false

    try {

      let body = {
        "configuration": configuration
      }

      console.log('body: ', body)

      await axios.put('/api/v1/configuration', body, { headers: { "Content-Type": "application/json" } }).then(res => {
        setLoadingDeployStatus(false)
        setSaveConfig(true)
        result = true

      }, err => {
        setLoadingDeployStatus(false)
        setShowErr(true)
        console.log(err)
        result = false
      });

    } catch (error) {
      setLoadingDeployStatus(false)
      setConfigInvalid(true)
      console.error(error)
      result = false
    }
    
    return result
  }


  const startDeploy = async () => {

    const saveSuccess = await saveConfiguration()

    if (saveSuccess) {
      setLoadingDeployStatus(true)

      if (selection === "Configure+Deploy") {
        createDeployment();
      } else if (selection === "Configure+Download") {
        createDownload();
      }
    }
  }


  useEffect(() => {
    const getEnviromentVariables = async () => {
      setLoadingEnviromentVariables(true)
      await axios.get('/api/v1/environment-variable').then(async res => {
        console.log(res)
        setLoadingEnviromentVariables(false)
        if (res.data.CPD_WIZARD_MODE === "existing-ocp") {
          setCpdWizardMode("existing-ocp")
          setSelection("Configure")
          setCurrentIndex(1)
        } else if (res.data.CPD_WIZARD_MODE === "deploy") {
          setCpdWizardMode("deploy")
          setSelection("Configure+Deploy")
          setCurrentIndex(1)
        } else if (res.data.CPD_WIZARD_MODE === "download") {
          setCpdWizardMode("download")
          setSelection("Configure+Download")
          setCurrentIndex(1)
        } else if (res.data.CPD_WIZARD_MODE === "configure") {
          setCpdWizardMode("configure")
          setSelection("Configure")
          setCurrentIndex(1)
        }

        if (res.data.CPD_WIZARD_PAGE_TITLE && res.data.CPD_WIZARD_PAGE_TITLE !== headerTitle) {
          setHeaderTitle(res.data.CPD_WIZARD_PAGE_TITLE)
        }
        if (res.data.STATUS_DIR) {
          setStatusDir(res.data.STATUS_DIR)
        }
        if (res.data.CONFIG_DIR) {
          setConfigDir(res.data.CONFIG_DIR)
        }

        if (res.data.CPD_CONTEXT) {
          setDeployerContext(res.data.CPD_CONTEXT)
          // Skip selection pane if context is openshift
          if (res.data.CPD_CONTEXT === "openshift" && !res.data.CPD_WIZARD_MODE) {
            // Check if OpenShift is already connected
            let ocConnected = await checkOpenShiftConnected();
            if (ocConnected === 1) {
              // Skip to Config page (step 2) if already connected
              setCurrentIndex(2)
            } else {
              // Go to OpenShift Login page (step 1) if not connected
              setCurrentIndex(1)
            }
          }
        }

      }, err => {
        setLoadingEnviromentVariables(false)
        setloadEnviromentVariablesErr(true)
        console.log(err)
      });
    }

    const checkInitialDeployerStatus = async () => {
      let deployerStatus = await checkDeployerStatus();
      if (deployerStatus === 1) {
        setCheckDeployerStatusErr(false)
        navigate('/status')
      }
    }

    getEnviromentVariables();
    checkInitialDeployerStatus();
    // eslint-disable-next-line
  }, []);

  const DeployerProgressIndicator = () => {
    return (
      <ProgressIndicator className="wizard-container__page-progress"
        vertical={false}
        currentIndex={currentIndex}
        spaceEqually={false}>

        <ProgressStep
          onClick={() => setCurrentIndex(0)}
          current={currentIndex === 0}
          label={'Selection'}
          description="Step 1"
        />

        <ProgressStep
          onClick={() => setCurrentIndex(1)}
          current={currentIndex === 1}
          label={'OCP Login'}
          description="Step 2"
        />

        <ProgressStep
          onClick={() => setCurrentIndex(2)}
          current={currentIndex === 2}
          label={'Config'}
          description="Step 3"
        />

        <ProgressStep
          onClick={() => setCurrentIndex(3)}
          current={currentIndex === 3}
          label={'Summary'}
          description="Step 4"
        />
      </ProgressIndicator>
    )
  }

  const ActionBySelect = () => {
    return (
      <>
        {selection === "Configure+Deploy" && <Button className="wizard-container__page-header-button" onClick={startDeploy} disabled={summaryLoading}>Save+Deploy</Button>}
        {selection === "Configure" && <Button className="wizard-container__page-header-button" onClick={saveConfiguration} disabled={summaryLoading}>Save</Button>}
        {selection === "Configure+Download" && <Button className="wizard-container__page-header-button" onClick={startDeploy} disabled={summaryLoading}>Save+Download</Button>}
      </>
    )
  }

  const errorEnviromentVariablesProps = () => ({
    kind: 'error',
    lowContrast: true,
    role: 'error',
    title: 'Unable to get variables from server.',
    hideCloseButton: false,
  });

  return (
    <>
      <div className="wizard-container">
        <div className="wizard-container__page">
          {loadEnviromentVariablesErr && <InlineNotification className="cpd-error"
            {...errorEnviromentVariablesProps()}
          />}
          {loadingEnviromentVariables && <Loading />}
          <div className='wizard-container__page-header'>
            <div className='wizard-container__page-header-title'>
              <h2>Deploy Wizard</h2>
              <div className='wizard-container__page-header-subtitle'>for IBM Cloud Pak</div>
            </div>
            <div>
              <Button className="wizard-container__page-header-button" onClick={() => navigate('/status')}>View Status</Button>
              <Button className="wizard-container__page-header-button" onClick={clickPrevious} disabled={currentIndex === 0}>Previous</Button>
              {currentIndex === 3 ?
                <Button className="wizard-container__page-header-button" onClick={saveConfiguration}>Save</Button>
                :
                null
              }
              {currentIndex === 3 ?
                <ActionBySelect />
                :
                <Button className="wizard-container__page-header-button" onClick={clickNext} disabled={wizardError}>Next</Button>
              }
            </div>
          </div>
          {loadingDeployStatus && <Loading />}
          <DeployerProgressIndicator />
          {currentIndex === 0 ? <Selection
            setSelection={setSelection}
            setCpdWizardMode={setCpdWizardMode}
            selection={selection}
          >
          </Selection> : null}

          {currentIndex === 1 ? <OpenShiftLogin
            cloudPlatform={cloudPlatform}
            setCloudPlatform={setCloudPlatform}
            selection={selection}
            OCPSettings={OCPSettings}
            setOCPSettings={setOCPSettings}
            setWizardError={setWizardError}
            ocLoginErr={ocLoginErr}
            isOcLoginCmdInvalid={isOcLoginCmdInvalid}
            setOcLoginCmdInvalid={setOcLoginCmdInvalid}
            envId={envId}
            setEnvId={setEnvId}
            checkDeployerStatusErr={checkDeployerStatusErr}
            cpdWizardMode={cpdWizardMode}
            registryHostname={registryHostname}
            setRegistryHostname={setRegistryHostname}
            registryPort={registryPort}
            setRegistryPort={setRegistryPort}
            registryNS={registryNS}
            setRegistryNS={setRegistryNS}
            registryUser={registryUser}
            setRegistryUser={setRegistryUser}
            registryPassword={registryPassword}
            setRegistryPassword={setRegistryPassword}
            portable={portable}
            setPortable={setPortable}
          >
          </OpenShiftLogin> : null}

          {currentIndex === 2 ? <CloudPak
            cloudPlatform={cloudPlatform}
            setCloudPlatform={setCloudPlatform}
            selection={selection}
            entitlementKey={entitlementKey}
            setEntitlementKey={setEntitlementKey}
            CPDCartridgesData={CPDCartridgesData}
            setCPDCartridgesData={setCPDCartridgesData}
            CPICartridgesData={CPICartridgesData}
            setCPICartridgesData={setCPICartridgesData}
            setWizardError={setWizardError}
            configuration={configuration}
            setConfiguration={setConfiguration}
            envId={envId}
            setEnvId={setEnvId}
            adminPassword={adminPassword}
            setAdminPassword={setAdminPassword}
            deployerContext={deployerContext}
            cp4dLicense={cp4dLicense}
            setCp4dLicense={setCp4dLicense}
            cp4dVersion={cp4dVersion}
            setCp4dVersion={setCp4dVersion}
            cp4iLicense={cp4iLicense}
            setCp4iLicense={setCp4iLicense}
            cp4iVersion={cp4iVersion}
            setCp4iVersion={setCp4iVersion}
          >
          </CloudPak> : null}

          {currentIndex === 3 ? <Summary
            cloudPlatform={cloudPlatform}
            CPDCartridgesData={CPDCartridgesData}
            setCPDCartridgesData={setCPDCartridgesData}
            CPICartridgesData={CPICartridgesData}
            setCPICartridgesData={setCPICartridgesData}
            setConfiguration={setConfiguration}
            configuration={configuration}
            envId={envId}
            summaryLoading={summaryLoading}
            setSummaryLoading={setSummaryLoading}
            configDir={configDir}
            statusDir={statusDir}
            tempSummaryInfo={tempSummaryInfo}
            setTempSummaryInfo={setTempSummaryInfo}
            configInvalid={configInvalid}
            setConfigInvalid={setConfigInvalid}
            showErr={showErr}
            setShowErr={setShowErr}
            saveConfig={saveConfig}
            setSaveConfig={setSaveConfig}
            deployerContext={deployerContext}
          >
          </Summary> : null}
        </div>
      </div>
    </>
  )
};

export default Wizard;
