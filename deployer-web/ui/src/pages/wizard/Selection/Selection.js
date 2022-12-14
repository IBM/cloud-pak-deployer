import axios from "axios";
import { Loading, RadioButton, RadioButtonGroup, InlineNotification } from "carbon-components-react";
import { useEffect, useState } from "react";


const Selection = ({setCpdWizardMode,
                    setSelection,
                    selection,
                    setCurrentIndex,
                   }) => {

    const [loadingEnviromentVariables, setLoadingEnviromentVariables] = useState(false)
    const [loadEnviromentVariablesErr, setloadEnviromentVariablesErr] = useState(false) 

    const errorEnviromentVariablesProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get Variables from server.',
      hideCloseButton: false,
    });


    useEffect(() => {        
      const getEnviromentVariables = async() => {
        setLoadingEnviromentVariables(true)
        await axios.get('/api/v1/environment-variable').then(res =>{   
          setLoadingEnviromentVariables(false)  
          if (res.data.CPD_WIZARD_MODE === "existing-ocp") {
            setCpdWizardMode("existing-ocp")
            setSelection("Configure+Deploy")
            setCurrentIndex(1)

          }
                
          
        }, err => {
          setLoadingEnviromentVariables(false) 
          setloadEnviromentVariablesErr(true)
          console.log(err)
        });    

      }
      getEnviromentVariables();
      // eslint-disable-next-line
    }, []);


    return (
      <>

      { loadEnviromentVariablesErr && <InlineNotification className="cpd-error"
          {...errorEnviromentVariablesProps()}        
            /> } 
      
      {loadingEnviromentVariables && <Loading /> }

      <div className="infra-title">Deployer Selection</div>        

      <RadioButtonGroup orientation="vertical"
         name="radio-button-group" 
         onChange={(value)=>{setSelection(value)}}
         defaultSelected={selection}  
         valueSelected={selection}         
         >
         <RadioButton labelText="Configure & Deploy" value="Configure+Deploy" id="400" />
         <RadioButton labelText="Configure & Download" value="Configure+Download" id="401"/>
         <RadioButton labelText="Configure" value="Configure" id="402" />     
      </RadioButtonGroup>

      </>
    );
  };

export default Selection;