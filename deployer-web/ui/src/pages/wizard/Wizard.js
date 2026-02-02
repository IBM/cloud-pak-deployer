import React from 'react';
import Infrastructure from './Infrastructure/Infrastructure';
import Selection from './Selection/Selection';
import './Wizard.scss'
import { useState, useEffect } from 'react';
import { ProgressIndicator, ProgressStep, ProgressBar, Button, InlineNotification, Loading, RadioButtonGroup, RadioButton, Table, TableHead, TableRow, TableBody, TableCell, TableHeader } from '@carbon/react';
import Summary from './Summary/Summary';
import axios from 'axios';
import CloudPak from './CloudPak/CloudPak';
import fileDownload from 'js-file-download';
import yaml from 'js-yaml';

const Wizard = ({ setHeaderTitle,
  headerTitle
}) => {

  //wizard index
  const [currentIndex, setCurrentIndex] = useState(0);
  const [wizardError, setWizardError] = useState(false);
  const [ocLoginErr, setOcLoginErr] = useState(false)
  const [checkDeployerStatusErr, setCheckDeployerStatusErr] = useState(false)

  //Environment variables loading
  const [loadingEnviromentVariables, setLoadingEnviromentVariables] = useState(false)
  const [loadEnviromentVariablesErr, setloadEnviromentVariablesErr] = useState(false)

  //DeployStart hidden wizard
  const [isDeployStart, setDeployStart] = useState(false);
  const [isDeployErr, setDeployErr] = useState(false);
  const [loadingDeployStatus, setLoadingDeployStatus] = useState(false)

  //Selection
  const [selection, setSelection] = useState('Configure+Deploy')
  const [cpdWizardMode, setCpdWizardMode] = useState('')

  //Infrastructure
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
  const [CP4DPlatformCheckBox, setCP4DPlatformCheckBox] = useState(false)
  const [CP4IPlatformCheckBox, setCP4IPlatformCheckBox] = useState(false)
  const [adminPassword, setAdminPassword] = useState('')

  //summary
  const [summaryLoading, setSummaryLoading] = useState(false)
  const [tempSummaryInfo, setTempSummaryInfo] = useState("")
  const [configInvalid, setConfigInvalid] = useState(false)
  const [showErr, setShowErr] = useState(false)

  //deploy
  const [deployerStatus, setDeployerStatus] = useState(true)    //true or false
  const [deployerPercentageCompleted, setDeployerPercentageCompleted] = useState(0)
  const [deployerStage, setDeployerStage] = useState('')
  const [deployerLastStep, setDeployerLastStep] = useState('')
  const [deployerCompletionState, setDeployerCompletionState] = useState('')
  const [deployerCurrentImage, setDeployerCurrentImage] = useState('')
  const [deployerImageNumber, setDeployerImageNumber] = useState('')

  const [scheduledJob, setScheduledJob] = useState(0)
  const [deployeyLog, setdeployeyLog] = useState('deployer-log')

  const [deployState, setDeployState] = useState([])
  const [configDir, setConfigDir] = useState('')
  const [statusDir, setStatusDir] = useState('')
  const [deployerContext, setDeployerContext] = useState('local')

  const [saveConfig, setSaveConfig] = useState(false)
  const [deletingJob, setDeletingJob] = useState(false)
  const [deleteJobSuccess, setDeleteJobSuccess] = useState(false)
  const [deleteJobError, setDeleteJobError] = useState('')

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
          setCurrentIndex(10)
          setDeployStart(true)
          setDeployErr(false)
          getDeployStatus()
          refreshStatus()
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
          setCurrentIndex(10)
          setDeployStart(true)
          setDeployErr(false)
          getDeployStatus()
          refreshStatus()
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

  const errorProps = () => ({
    kind: 'error',
    lowContrast: true,
    role: 'error',
    title: 'Get error to start IBM Cloud Pak deployment. ',
    hideCloseButton: false,
  });

  const successSaveConfigProps = () => ({
    kind: 'success',
    lowContrast: true,
    role: 'success',
    title: 'The configuration file is saved successfully!',
    hideCloseButton: false,
  });

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
      setDeployStart(true)
      setDeployErr(false)
      setCurrentIndex(10)
      getDeployStatus()
      refreshStatus()

    }, err => {
      setLoadingDeployStatus(false)
      console.log(err)
      setDeployStart(true)
      setDeployErr(true)
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
      setDeployStart(true)
      setDeployErr(false)
      setCurrentIndex(10)
      getDeployStatus()
      refreshStatus()

    }, err => {
      setLoadingDeployStatus(false)
      console.log(err)
      setDeployStart(true)
      setDeployErr(true)
    });
  }

  const saveConfiguration = async () => {
    setLoadingDeployStatus(true)
    let body = {}
    let result = {}

    try {

      let body = {
        "configuration": configuration
      }

      console.log('body: ', body)

      await axios.put('/api/v1/configuration', body, { headers: { "Content-Type": "application/json" } }).then(res => {
        setLoadingDeployStatus(false)
        setSaveConfig(true)

      }, err => {
        setLoadingDeployStatus(false)
        setShowErr(true)
        console.log(err)
      });

    } catch (error) {
      setLoadingDeployStatus(false)
      setConfigInvalid(true)
      console.error(error)
    }
  }


  const startDeploy = async () => {

    saveConfiguration()

    if (saveConfig === true) {
      setLoadingDeployStatus(true)

      if (selection === "Configure+Deploy") {
        createDeployment();
      } else if (selection === "Configure+Download") {
        createDownload();
      }
    }
  }

  const getDeployStatus = async () => {
    if (isDeployErr)
      return
    await axios.get('/api/v1/deployer-status').then(res => {
      setDeployerStatus(res.data.deployer_active)
      if (res.data.deployer_active) {
        setDeployerPercentageCompleted(res.data.percentage_completed)
      } else {
        setDeployerPercentageCompleted(100)
      }

      if (res.data.deployer_stage) {
        setDeployerStage(res.data.deployer_stage)
      } else {
        setDeployerStage("")
      }
      if (res.data.last_step) {
        setDeployerLastStep(res.data.last_step)
      } else {
        setDeployerLastStep("")
      }
      if (res.data.service_state) {
        setDeployState(res.data.service_state)
      }
      if (res.data.completion_state) {
        setDeployerCompletionState(res.data.completion_state)
      }
      if (res.data.mirror_current_image) {
        setDeployerCurrentImage(res.data.mirror_current_image)
      }
      if (res.data.mirror_number_images) {
        setDeployerImageNumber(res.data.mirror_number_images)
      }
    }, err => {
      console.log(err)
    });
  }

  const refreshStatus = () => {
    setScheduledJob(setInterval(() => {
      getDeployStatus()
    }, 5000))
  }

  const deleteDeployerJob = async () => {
    if (deployerContext !== 'openshift') {
      setDeleteJobError('Delete operation is only available for OpenShift deployments')
      return
    }

    if (!window.confirm('Are you sure you want to delete the cloud-pak-deployer job? This will stop the current deployment.')) {
      return
    }

    setDeletingJob(true)
    setDeleteJobError('')
    setDeleteJobSuccess(false)

    try {
      await axios.delete('/api/v1/delete-deployer-job').then(res => {
        setDeletingJob(false)
        setDeleteJobSuccess(true)
        setDeleteJobError('')
        // Refresh the status after deletion
        setTimeout(() => {
          getDeployStatus()
          setDeleteJobSuccess(false)
        }, 2000)
      }, err => {
        setDeletingJob(false)
        setDeleteJobSuccess(false)
        const errorMsg = err.response?.data?.message || 'Failed to delete deployer job'
        setDeleteJobError(errorMsg)
        console.log(err)
      })
    } catch (error) {
      setDeletingJob(false)
      setDeleteJobSuccess(false)
      setDeleteJobError('An error occurred while deleting the job')
      console.log(error)
    }
  }

  const downloadLog = async () => {
    const body = { "deployerLog": deployeyLog }
    const headers = { 'Content-Type': 'application/json; application/octet-stream', responseType: 'blob' }
    await axios.post('/api/v1/download-log', body, headers).then(res => {
      if (deployeyLog === 'all-logs') {
        fileDownload(res.data, "cloud-pak-deployer-logs.tar.gz")
      } else {
        fileDownload(res.data, "cloud-pak-deployer.log")
      }
    }, err => {
      console.log(err)
    });
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
              // Go to Infrastructure page (step 1) if not connected
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
        setCurrentIndex(10)
        setDeployStart(true)
        setDeployErr(false)
        getDeployStatus()
        refreshStatus()
      }
    }

    getEnviromentVariables();
    checkInitialDeployerStatus();
    // eslint-disable-next-line
  }, []);

  useEffect(() => {
    if (isDeployStart && !isDeployErr) {
      if (!deployerStatus) {
        clearInterval(scheduledJob)
      }
    }
    return () => {
      clearInterval(scheduledJob)
    }
    // eslint-disable-next-line
  }, [deployerStatus])

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

  const oneDimensionArray2twoDimensionArray = (baseArray) => {
    let len = baseArray.length;
    let n = 9;
    let lineNum = len % n === 0 ? len / n : Math.floor((len / n) + 1);
    let res = [];
    for (let i = 0; i < lineNum; i++) {
      let temp = baseArray.slice(i * n, i * n + n);
      res.push(temp);
    }
    return res;
  }

  const headers = ['Service', 'State'];
  const tables = oneDimensionArray2twoDimensionArray(deployState);

  const ActionBySelect = () => {
    return (
      <>
        {selection === "Configure+Deploy" && <Button className="wizard-container__page-header-button" onClick={startDeploy} disabled={summaryLoading}>Save+Deploy</Button>}
        {selection === "Configure" && <Button className="wizard-container__page-header-button" onClick={saveConfiguration} disabled={summaryLoading}>Save</Button>}
        {selection === "Configure+Download" && <Button className="wizard-container__page-header-button" onClick={startDeploy} disabled={summaryLoading}>Save+Download</Button>}
      </>
    )
  }

  const DeployStats = () => {
    return (
      <>
        <div className="deploy-stats-container">
          <div className="deploy-stats-left">
            <div className="deploy-status">Deployer Status:</div>

            {!deployerStatus && <div className="deploy-key" >
              <div>Completion state:</div>
              <div className="deploy-value">{deployerCompletionState}</div>
            </div>}

            <div className="deploy-key" >
              <div>State:</div>
              <div className="deploy-value">{deployerStatus ? 'ACTIVE' : 'INACTIVE'}</div>
            </div>

            {deployerStage && <div className="deploy-key" >
              <div>Current Stage:</div>
              <div className="deploy-value">{deployerStage}</div>
            </div>}

            {deployerLastStep && <div className="deploy-key" >
              <div>Current Task:</div>
              <div className="deploy-value">{deployerLastStep}</div>
            </div>}

            {deployerCurrentImage && <div className="deploy-key" >
              <div>Current Image:</div>
              <div className="deploy-value">{deployerCurrentImage}</div>
            </div>}

            {deployerImageNumber && <div className="deploy-key" >
              <div>Mirror Images Number:</div>
              <div className="deploy-value">{deployerImageNumber}</div>
            </div>}


            <div className="deploy-key">
              <div>Deployer Log:</div>
              <div className="deploy-value">
                <RadioButtonGroup
                  //orientation="vertical"
                  onChange={(value) => { setdeployeyLog(value) }}
                  legendText=""
                  name="log-options-group"
                  defaultSelected={deployeyLog}>
                  <RadioButton
                    labelText="Deployer log"
                    value="deployer-log"
                    id="log-radio-1"
                  />
                  <RadioButton
                    labelText="All logs"
                    value="all-logs"
                    id="log-radio-2"
                  />
                </RadioButtonGroup>
              </div>

            </div>
            <div className="deploy-key" >
              <Button onClick={downloadLog}>Download logs</Button>
            </div>

            <div className="deploy-item">Deployer Progress:
              <ProgressBar
                label=""
                helperText=""
                value={deployerPercentageCompleted}
              />
            </div>
          </div>

          <div className="deploy-stats-right">
            {deployerContext === 'openshift' && (
              <div className="deploy-stop-button-container">
                <Button
                  kind="danger"
                  onClick={deleteDeployerJob}
                  disabled={deletingJob}
                >
                  {deletingJob ? 'Deleting...' : 'Stop Deployer job'}
                </Button>
              </div>
            )}

            {deleteJobSuccess && (
              <InlineNotification
                kind="success"
                title="Success"
                subtitle="Deployer job deleted successfully"
                onCloseButtonClick={() => setDeleteJobSuccess(false)}
              />
            )}

            {deleteJobError && (
              <InlineNotification
                kind="error"
                title="Error"
                subtitle={deleteJobError}
                onCloseButtonClick={() => setDeleteJobError('')}
              />
            )}
          </div>
        </div>
        <div>
          {deployState.length > 0 &&
            <div className="deploy-item">Status of services:
              <div className="deploy-item__state">
                {tables.map((table) => (

                  <div className="deploy-item__state-table">
                    <Table size="md" useZebraStyles={false}>
                      <TableHead>
                        <TableRow>
                          {headers.map((header) => (
                            <TableHeader id={header.key} key={header}>
                              {header}
                            </TableHeader>
                          ))}
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {table.map((row) => (
                          <TableRow key={row.id}>
                            {Object.keys(row)
                              .filter((key) => key !== 'id')
                              .map((key) => {
                                return <TableCell key={key}>{row[key]}</TableCell>;
                              })}
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                ))
                }
              </div>
            </div>
          }
        </div>
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
            {isDeployStart ? null :
              <div>
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
            }
          </div>
          {loadingDeployStatus && <Loading />}
          {
            isDeployStart ?
              //Deploy Process
              isDeployErr ?
                <InlineNotification className="deploy-error"
                  {...errorProps()}
                />
                :
                <div>
                  {selection !== "Configure" && <DeployStats />}
                  {selection === "Configure" && saveConfig && <InlineNotification className="deploy-error"
                    {...successSaveConfigProps()}
                  />
                  }
                </div>
              :
              //Wizard Process
              <DeployerProgressIndicator />
          }
          {currentIndex === 0 ? <Selection
            setSelection={setSelection}
            setCpdWizardMode={setCpdWizardMode}
            selection={selection}
          >
          </Selection> : null}

          {currentIndex === 1 ? <Infrastructure
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
          </Infrastructure> : null}

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
            CP4DPlatformCheckBox={CP4DPlatformCheckBox}
            CP4IPlatformCheckBox={CP4IPlatformCheckBox}
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
          >
          </Summary> : null}
        </div>
      </div>
    </>
  )
};

export default Wizard;
