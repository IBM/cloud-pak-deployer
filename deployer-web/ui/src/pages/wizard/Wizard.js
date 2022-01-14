import React from 'react';
import Infrastructure from './Infrastructure/Infrastructure';
import Storage from './Storage/Storage';
import './Wizard.scss'
import { useState } from 'react';
import { ProgressIndicator, ProgressStep, Button, InlineNotification } from 'carbon-components-react';
import Summary from './Summary/Summary';
import axios from 'axios';
import CloudPak from './CP4D/CloudPak';

const Wizard = () => {

  let [currentIndex, setCurrentIndex] = useState(0);
  let [showLog, setShowLog] = useState(false);
  let [showErr, setShowErr] = useState(false)

  const [cloudPlatform, setCloudPlatform] = useState('ibm-cloud');
  const [IBMAPIKey, setIBMAPIKey] = useState('')
  const [envId, setEnvId] = useState('')
  const [entilementKey, setEntilementKey] = useState('')
  
  
  const setIndex = (index) =>{
    console.log(index)
    setCurrentIndex(index)
  }

  const clickPrevious = ()=> {
    if (currentIndex >= 1)
       setCurrentIndex(currentIndex-1)
  }

  const clickNext = ()=> {
    if (currentIndex <= 2)
      setCurrentIndex(currentIndex+1)
  }
  
  const createDeployment = () => {

    const body = {
      "env":{
          "ibmCloudAPIKey":IBMAPIKey,
          "entilementKey":entilementKey,
      },
      "cloud": cloudPlatform,
      "envId": envId,
      "region":"us-east",
      "configDir":"/tmp/config",
      "statusDir":"/tmp/status"
    }

    axios.post('/api/v1/deploy', body).then(res =>{
        //console.log(res)
        setShowLog(true)
        setCurrentIndex(-1)
    }, err => {
        setShowErr(true)
        setShowLog(true)
        setCurrentIndex(-1)
    });
    
  }

  const changeValue = ({cloudPlatform, IBMAPIKey, envId, entilementKey}) => {
    if (cloudPlatform)
      setCloudPlatform(cloudPlatform)
    if (IBMAPIKey)
      setIBMAPIKey(IBMAPIKey)
    if (envId)
      setEnvId(envId)
    if (entilementKey)
      setEntilementKey(entilementKey)
  }

  const onCloseButtonClick = () => {

  } 

  //const 

  const errorProps = () => ({
    kind: 'error',
    lowContrast: true,
    role: 'error',
    title: 'Get Error to start IBM Cloud Pak deployment. ',
    hideCloseButton: true,
    //onClose:'onClose',
    //onCloseButtonClick: onCloseButtonClick,
  }); 
  
  const successProps = () => ({
    kind: 'success',
    lowContrast: true,
    role: 'success',
    title: 'IBM Cloud Pak deployment was submitted. ',
    hideCloseButton: true,
    //onClose:'onClose',
    //onCloseButtonClick: onCloseButtonClick,
  });

  return (
    <>
    <div className="wizard-container">
      <div className="wizard-container__page">
        <div className='wizard-container__page-header'>
          <div className='wizard-container__page-header-title'>         
            <h2>Deploy Wizard</h2>
            <div className='wizard-container__page-header-subtitle'>IBM Cloud Pak</div>                      
          </div>
          { showLog ? null: 
          <div>
            <Button className="wizard-container__page-header-button" onClick={clickPrevious}>Previous</Button>
            {currentIndex === 3 ?
              <Button className="wizard-container__page-header-button" onClick={createDeployment}>Create</Button>
              :
              <Button className="wizard-container__page-header-button" onClick={clickNext}>Next</Button>
            }            
          </div>
          }          
        </div>        
        {
          showLog ? 
              showErr ?
              <InlineNotification className="summary-error"
                    {...errorProps()}        
                />  
                :
              <InlineNotification className="summary-error"
                {...successProps()}        
            />  

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
            onClick={() => setIndex(1)}
            current={currentIndex === 1}
            label={'Storage'}
            description="Step 2"
          />

          <ProgressStep
            onClick={() => setIndex(2)}
            current={currentIndex === 2}
            label={'Cloud Pak'}
            description="Step 3"
          />

          <ProgressStep
            onClick={() => setIndex(3)}
            current={currentIndex === 3}
            label={'Summary'}
            description="Step 4"
          />    
          </ProgressIndicator> 
          
        }          
          {currentIndex === 0 ? <Infrastructure changeValue={changeValue}></Infrastructure> : null}
          {currentIndex === 1 ? <Storage></Storage> : null}    
          {currentIndex === 2 ? <CloudPak></CloudPak> : null}    
          {currentIndex === 3 ? <Summary envId={envId} cloud={cloudPlatform}></Summary> : null}          
    
      </div> 
    </div>
     </>
  )
};

export default Wizard;
  