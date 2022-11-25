import React from 'react';
import Infrastructure from './Infrastructure/Infrastructure';
import Storage from './Storage/Storage';
import './Wizard.scss'
import { useState, useEffect } from 'react';
import { ProgressIndicator, ProgressStep, Button, InlineNotification, Loading, RadioButtonGroup, RadioButton} from 'carbon-components-react';
import ProgressBar from 'carbon-components-react/lib/components/ProgressBar'
import Summary from './Summary/Summary';
import axios from 'axios';
import CloudPak from './CloudPak/CloudPak';
import fileDownload from 'js-file-download'

const Wizard = () => {

   //wizard index
  const [currentIndex, setCurrentIndex] = useState(0);
  const [wizardError, setWizardError] = useState(true);
  const [ocLoginErr, setOcLoginErr] = useState(false)

  //DeployStart hidden wizard
  const [isDeployStart, setDeployStart] = useState(false);
  const [isDeployErr, setDeployErr] = useState(false);
  const [loadingDeployStatus, setLoadingDeployStatus] = useState(false)

  //Infrastructure
  const [cloudPlatform, setCloudPlatform] = useState("existing-ocp")
  const [configuration, setConfiguration] = useState({})
  const [locked, setLocked] = useState(false)
  const [envId, setEnvId] = useState("")
  //---IBM Cloud
  const [IBMCloudSettings, setIBMCloudSettings] = useState({
    IBMAPIKey: '',
    region: '',
  })
  //---AWS
  const [AWSSettings, setAWSSettings] = useState({
    accessKeyID: '',
    secretAccessKey:'',
  })
  //---Existing OpenShift
  const [OCPSettings, setOCPSettings] = useState({
    ocLoginCmd:'',
  })  
  const [isOcLoginCmdInvalid, setOcLoginCmdInvalid] = useState(false)

  //Storage
  const [storage, setStorage] = useState([])
  const [storagesOptions, setStoragesOptions] = useState([])

  //Cloud Pak
  const [CPDCartridgesData, setCPDCartridgesData] = useState([])
  const [CPICartridgesData, setCPICartridgesData] = useState([])
  const [entitlementKey, setEntitlementKey] = useState('')
  const [CP4DPlatformCheckBox, setCP4DPlatformCheckBox] = useState(false)  
  const [CP4IPlatformCheckBox, setCP4IPlatformCheckBox] = useState(false)

  const [cp4dLicense, setCp4dLicense] = useState(false)
  const [cp4iLicense, setCp4iLicense] = useState(false)
  const [cp4dVersion, setCp4dVersion] = useState("")
  const [cp4iVersion, setCp4iVersion] = useState("")

  //deploy
  const [deployerStatus, setDeployerStatus] = useState(true)    //true or false
  const [deployerPercentageCompleted, setDeployerPercentageCompleted] = useState('')
  const [deployerStage, setDeployerStage] = useState('')
  const [deployerLastStep, setDeployerLastStep] = useState('')

  const [scheduledJob, setScheduledJob] = useState(0)

  const [deployeyLog, setdeployeyLog] = useState('deployer-log')

  const clickPrevious = ()=> {
    if (currentIndex >= 1)
       setCurrentIndex(currentIndex - 1)
  }

  const testOcLoginCmd = async() => {
    let patt = /oc\s+login\s+/;    
    if (!patt.test(OCPSettings.ocLoginCmd.trim())) {
      setOcLoginCmdInvalid(true)
      setLoadingDeployStatus(false) 
      return
    }   
    setOcLoginCmdInvalid(false)
    const body={
      "oc_login_command": OCPSettings.ocLoginCmd
    }
    let result=-1
    await axios.post('/api/v1/oc-login', body).then(res =>{     
      result=res.data.code            
      if (result!==0) {
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

  const clickNext = async()=> {
    if (currentIndex === 0 && cloudPlatform === "existing-ocp") {
      setLoadingDeployStatus(true) 
      let result=await testOcLoginCmd();
      if (result!==0) {
        return
      }
    }

    setWizardError(true)
    if (currentIndex <= 2)
      setCurrentIndex(currentIndex + 1)
  }

  const createDeployment = async () => {
    setLoadingDeployStatus(true)
    const body = {
      "env":{
          "ibmCloudAPIKey":IBMCloudSettings.IBMAPIKey
      },
      "entitlementKey": entitlementKey,
      "cloud": cloudPlatform,
      "envId": envId,
      "oc_login_command": OCPSettings.ocLoginCmd.trim(),
      "region": IBMCloudSettings.region,
    }
    
    setCurrentIndex(-1)
    await axios.post('/api/v1/deploy', body).then(res =>{
        setLoadingDeployStatus(false)    
        setDeployStart(true)  
        setDeployErr(false)
        getDeployStatus()
        refreshStatus()        
  
    }, err => {
        setLoadingDeployStatus(false)    
        console.log(err)
        setDeployStart(true)
        setDeployErr(true)
    });    
  }

  const errorProps = () => ({
    kind: 'error',
    lowContrast: true,
    role: 'error',
    title: 'Get error to start IBM Cloud Pak deployment. ',
    hideCloseButton: false,
  }); 
  
  const successProps = () => ({
    kind: 'success',
    lowContrast: true,
    role: 'success',
    title: 'IBM Cloud Pak deployment was submitted successfully. ',
    hideCloseButton: false,
  });

  const getDeployStatus = async() => {
    if (isDeployErr)
      return 

    await axios.get('/api/v1/deployer-status').then(res =>{
        setDeployerStatus(res.data.deployer_active)
        setDeployerPercentageCompleted(res.data.percentage_completed)
        setDeployerStage(res.data.deployer_stage)
        setDeployerLastStep(res.data.last_step)
    }, err => {
        console.log(err)        
    });
  }

  const refreshStatus = ()=>{
    setScheduledJob(setInterval(() => {
        getDeployStatus()
      }, 5000))
  }

  const downloadLog = async() => {
    const body = {"deployerLog":deployeyLog}
    const headers = {'Content-Type': 'application/json; application/octet-stream', responseType: 'blob'}
    await axios.post('/api/v1/download-log', body, headers).then(res =>{
      if (deployeyLog === 'all-logs') {
        fileDownload(res.data, "logs.zip")
      }else {
        fileDownload(res.data, "deployer-state.out")
      }       
  }, err => {
      console.log(err)        
  });

  }

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
  },[deployerStatus])

  const DeployerProgressIndicator = () => {
    return (
      <ProgressIndicator className="wizard-container__page-progress"
          vertical={false}
          currentIndex={currentIndex}
          spaceEqually={false}>  

          <ProgressStep
            onClick={() => setCurrentIndex(0)}
            current={currentIndex === 0}
            label={'Infrastructure'}
            description="Step 1"
          />

          <ProgressStep
            onClick={() => setCurrentIndex(1)}
            current={currentIndex === 1}
            label={'Storage'}
            description="Step 2"
          />

          <ProgressStep
            onClick={() => setCurrentIndex(2)}
            current={currentIndex === 2}
            label={'Cloud Pak'}
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

  return (
    <>
     <div className="wizard-container">
      <div className="wizard-container__page">
        <div className='wizard-container__page-header'>
          <div className='wizard-container__page-header-title'>         
            <h2>Deploy Wizard</h2>
            <div className='wizard-container__page-header-subtitle'>IBM Cloud Pak</div>                      
          </div>
          { isDeployStart ? null: 
          <div>
            <Button className="wizard-container__page-header-button" onClick={clickPrevious} disabled={currentIndex === 0}>Previous</Button>
            {currentIndex === 3 ?
              <Button className="wizard-container__page-header-button" onClick={createDeployment}>Deploy</Button>
              :
              <Button className="wizard-container__page-header-button" onClick={clickNext} disabled={wizardError}>Next</Button>
            }            
          </div>
          }          
        </div> 
        {loadingDeployStatus && <Loading /> }            
        {
          isDeployStart ? 
            //Deploy Process
            isDeployErr ?
              <InlineNotification className="deploy-error"
                {...errorProps()}        
              />  
              :
              <>
              <InlineNotification className="deploy-error"
                {...successProps()}        
              />   

              <div>
                <div className="deploy-status">Deployer Status:</div>

                <div className="deploy-key" >
                  <div>Deployer:</div>
                  <div className="deploy-value">{deployerStatus?'ACTIVE':'INACTIVE'}</div> 
                </div>
                <div className="deploy-key" >
                  <div>Current Stage:</div>
                  <div className="deploy-value">{deployerStage}</div> 
                </div>
                <div className="deploy-key" >
                  <div>Current Task:</div>
                  <div className="deploy-value">{deployerLastStep}</div> 
                </div>
                <div className="deploy-key">
                  <div>Deployer Log:</div>
                  <div className="deploy-value">
                    <RadioButtonGroup
                        //orientation="vertical"
                        onChange={(value)=>{setdeployeyLog(value)}}
                        legendText=""
                        name="log-options-group"
                        defaultSelected={deployeyLog}>
                        <RadioButton
                          labelText="Deployer Log Only"
                          value="deployer-log"
                          id="log-radio-1"
                        />
                        <RadioButton
                          labelText="Deployer All Logs"
                          value="all-logs"
                          id="log-radio-2"
                        />
                      </RadioButtonGroup>
                  </div> 
                                                     
                </div>
                <div className="deploy-key" >
                  <Button onClick={downloadLog}>Download</Button>
                </div>

                <div className="deploy-item">Deployer Progress:
                  <ProgressBar
                    label=""
                    helperText=""
                    value={deployerPercentageCompleted}
                  />
                </div>
              </div>        

              </>
          :
          //Wizard Process
          <DeployerProgressIndicator />                   
        } 
      
        {currentIndex === 0 ? <Infrastructure
                                    cloudPlatform={cloudPlatform} 
                                    setCloudPlatform={setCloudPlatform} 
                                    IBMCloudSettings={IBMCloudSettings}
                                    setIBMCloudSettings={setIBMCloudSettings}                                      
                                    AWSSettings={AWSSettings}
                                    setAWSSettings={setAWSSettings}
                                    OCPSettings={OCPSettings}
                                    setOCPSettings={setOCPSettings}                                    
                                    setWizardError={setWizardError}
                                    ocLoginErr={ocLoginErr}
                                    configuration={configuration}
                                    setConfiguration={setConfiguration}
                                    locked={locked}
                                    setLocked={setLocked}
                                    isOcLoginCmdInvalid={isOcLoginCmdInvalid}
                                    setOcLoginCmdInvalid={setOcLoginCmdInvalid}
                                    envId={envId}
                                    setEnvId={setEnvId}
                              >
                              </Infrastructure> : null} 
        {currentIndex === 1 ? <Storage 
                                    cloudPlatform={cloudPlatform} 
                                    setStorage={setStorage} 
                                    storage={storage} 
                                    storagesOptions={storagesOptions} 
                                    setStoragesOptions={setStoragesOptions}
                                    setWizardError={setWizardError}
                                    configuration={configuration}
                                    locked={locked}
                              >                                    
                              </Storage> : null}    
        {currentIndex === 2 ? <CloudPak
                                    entitlementKey={entitlementKey} 
                                    setEntitlementKey={setEntitlementKey}
                                    CPDCartridgesData={CPDCartridgesData}
                                    setCPDCartridgesData={setCPDCartridgesData}
                                    CPICartridgesData={CPICartridgesData}
                                    setCPICartridgesData={setCPICartridgesData}                                    
                                    setWizardError={setWizardError}
                                    configuration={configuration}
                                    locked={locked}
                                    cp4dLicense={cp4dLicense}
                                    cp4iLicense={cp4iLicense}
                                    cp4dVersion={cp4dVersion}
                                    cp4iVersion={cp4iVersion}
                                    setCp4dLicense={setCp4dLicense}
                                    setCp4iLicense={setCp4iLicense}
                                    setCp4dVersion={setCp4dVersion}
                                    setCp4iVersion={setCp4iVersion}
                                    CP4DPlatformCheckBox={CP4DPlatformCheckBox}
                                    CP4IPlatformCheckBox={CP4IPlatformCheckBox}
                                    setCP4DPlatformCheckBox={setCP4DPlatformCheckBox}
                                    setCP4IPlatformCheckBox={setCP4IPlatformCheckBox}
                              >
                              </CloudPak> : null}    
        {currentIndex === 3 ? <Summary 
                                    cloudPlatform={cloudPlatform} 
                                    IBMCloudSettings={IBMCloudSettings}                                                                      
                                    AWSSettings={AWSSettings}
                                    OCPSettings={OCPSettings}
                                    storage={storage} 
                                    CPDCartridgesData={CPDCartridgesData}
                                    setCPDCartridgesData={setCPDCartridgesData}
                                    CPICartridgesData={CPICartridgesData}
                                    setCPICartridgesData={setCPICartridgesData}
                                    configuration={configuration}
                                    locked={locked}
                                    cp4dLicense={cp4dLicense}
                                    cp4iLicense={cp4iLicense}
                                    cp4dVersion={cp4dVersion}
                                    cp4iVersion={cp4iVersion}
                                    envId={envId}
                                    CP4DPlatformCheckBox={CP4DPlatformCheckBox}
                                    CP4IPlatformCheckBox={CP4IPlatformCheckBox}
                              >
                              </Summary> : null}       
      </div> 
    </div>
    </>
  )
};

export default Wizard;
  