import React from 'react';
import Infrastructure from './Infrastructure/Infrastructure';
import Storage from './Storage/Storage';
import './Wizard.scss'
import { useState, useEffect, useRef } from 'react';
import { ProgressIndicator, ProgressStep, Button, InlineNotification, Loading, TextArea} from 'carbon-components-react';
import Summary from './Summary/Summary';
import axios from 'axios';
import CloudPak from './CP4D/CloudPak';

const Wizard = () => {

  //wizard index
  const [currentIndex, setCurrentIndex] = useState(0);
  const [wizardError, setWizardError] = useState(false)

  //DeployStart hidden wizard
  const [isDeployStart, setDeployStart] = useState(false);
  const [isDeployErr, setDeployErr] = useState(false);
  const [loadingDeployStatus, setLoadingDeployStatus] = useState(false)

  //Step 1
  const [cloudPlatform, setCloudPlatform] = useState('ibm-cloud')
  //--ibm cloud
  const [IBMCloudSettings, setIBMCloudSettings] = useState({
    IBMAPIKey: '',
    envId: '',
    entilementKey: '',
    region: '',
  })
  //--AWS
  const [AWSSecurityKey, setAWSSecurityKey] = useState('')
  //Step 2
  const [storage, setStorage] = useState([])
  const [storagesOptions, setStoragesOptions] = useState([])
  //Step 3
  const [CPDData, setCPDData] = useState([])

  //Step 4
  const [deployLog, setDeployLog] = useState('')

  const logsRef = useRef(null);

  const clickPrevious = ()=> {
    if (currentIndex >= 1)
       setCurrentIndex(currentIndex - 1)
  }

  const clickNext = ()=> {
    if (currentIndex <= 2)
      setCurrentIndex(currentIndex + 1)
  }

  const createDeployment = async () => {
    setLoadingDeployStatus(true)
    const body = {
      "env":{
          "ibmCloudAPIKey":IBMCloudSettings.IBMAPIKey,
          "entilementKey":IBMCloudSettings.entilementKey,
      },
      "cloud": cloudPlatform,
      "envId": IBMCloudSettings.envId,
      "region":IBMCloudSettings.region,
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

  const updateWizardError = (e)=>{
    setWizardError(e)
  }
  
  const updateInfraValue = ({cloudPlatform, region}) => {
      if (cloudPlatform){
        setCloudPlatform(cloudPlatform)
      }      
      if (region) {
        setIBMCloudSettings({...IBMCloudSettings, region})
      }
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
  }, [])

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
        }          
          {currentIndex === 0 ? <Infrastructure setIBMCloudSettings={setIBMCloudSettings} cloudPlatform={cloudPlatform} updateInfraValue={updateInfraValue} updateWizardError={updateWizardError} IBMCloudSettings={IBMCloudSettings}></Infrastructure> : null} 
          {currentIndex === 1 ? <Storage cloudPlatform={cloudPlatform} setStorage={setStorage} storage={storage} storagesOptions={storagesOptions} setStoragesOptions={setStoragesOptions}></Storage> : null}    
          {currentIndex === 2 ? <CloudPak CPDData={CPDData} setCPDData={setCPDData}></CloudPak> : null}    
          {currentIndex === 3 ? <Summary envId={IBMCloudSettings.envId} cloudPlatform={cloudPlatform} storage={storage} region={IBMCloudSettings.region} CPDData={CPDData}></Summary> : null}          
    
      </div> 
    </div>
     </>
  )
};

export default Wizard;
  