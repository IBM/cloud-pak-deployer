import React from 'react';
import Infrastructure from './Infrastructure/Infrastructure';
import Storage from './Storage/Storage';
import './Wizard.scss'
import { useState, useEffect, useRef } from 'react';
import { ProgressIndicator, ProgressStep, Button, InlineNotification, Loading, TextArea} from 'carbon-components-react';
import Summary from './Summary/Summary';
import axios from 'axios';
import CloudPak from './CloudPak/CloudPak';

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
  //---IBM Cloud
  const [IBMCloudSettings, setIBMCloudSettings] = useState({
    IBMAPIKey: '',
    envId: "",
    region: '',
  })
  //---AWS
  const [AWSSettings, setAWSSettings] = useState({
    accessKeyID: '',
    envId: "",
    secretAccessKey:'',
  })
  //---Existing OpenShift
  const [OCPSettings, setOCPSettings] = useState({
    ocLoginCmd:'',
    envId: "",
  })  

  //Storage
  const [storage, setStorage] = useState([])
  const [storagesOptions, setStoragesOptions] = useState([])

  //Cloud Pak
  // const [OCPData, setOCPData] = useState([])
  const [CPDCartridgesData, setCPDCartridgesData] = useState([])
  const [CPICartridgesData, setCPICartridgesData] = useState([])
  const [entitlementKey, setEntitlementKey] = useState('')

  //Summary
  const [deployLog, setDeployLog] = useState('')

  const [isOcLoginCmdInvalid, setOcLoginCmdInvalid] = useState(false)

  const logsRef = useRef(null);

  const clickPrevious = ()=> {
    //setWizardError(false)
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
      "envId": OCPSettings.envId,
      "oc_login_command": OCPSettings.ocLoginCmd.trim(),
      "region": IBMCloudSettings.region,
    }
    //console.log("deploy", body)
    
    setCurrentIndex(-1)
    await axios.post('/api/v1/deploy', body).then(res =>{
        //console.log(res)  
        setDeployStart(true)  
        fetchLog()
        refreshLog()    
    }, err => {
        console.log(err)
        setDeployStart(true)
        setDeployErr(true)
    });
    setLoadingDeployStatus(false)    
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

  const fetchLog = async() => {
    if (isDeployErr)
      return 
    await axios.get('/api/v1/logs').then(res =>{
        setDeployLog(res.data.logs)            
    }, err => {
        console.log(err)        
    });
  }

  let scheduledJob;
  const refreshLog = ()=>{
    scheduledJob = setInterval(() => {
      fetchLog()
      logsRef.current.scrollTo({left:0, top: logsRef.current.scrollHeight, behavior: 'smooth'})
    }, 2000);
  }

  useEffect(() => {    
    return () => {
      clearInterval(scheduledJob)
    }
    // eslint-disable-next-line
  }, [])

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

              <h4>Logs:</h4>
              <div>
                <TextArea ref={logsRef}
                        rows={20}
                        className="wizard-logs"
                        hideLabel={true}
                        placeholder={deployLog}   
                        labelText=""                    
                    />
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
                              >
                              </Summary> : null}       
      </div> 
    </div>
    </>
  )
};

export default Wizard;
  