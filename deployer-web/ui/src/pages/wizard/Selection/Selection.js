import axios from "axios";
import { Loading, RadioButton, RadioButtonGroup, InlineNotification } from "carbon-components-react";
import { useEffect, useState } from "react";


const Selection = ({setCpdWizardMode,
                    setSelection,
                    selection,
                    setCurrentIndex,
                    setConfigDir,
                    setStatusDir,
                    setHeaderTitle,
                    headerTitle

                   }) => {

    const [loadingEnviromentVariables, setLoadingEnviromentVariables] = useState(false)
    const [loadEnviromentVariablesErr, setloadEnviromentVariablesErr] = useState(false) 

    const selectOnChange = (e) =>{
      setSelection(e)
      if (e==="Configure") {
        setCpdWizardMode("existing-ocp")
      }
    }

    const errorEnviromentVariablesProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get variables from server.',
      hideCloseButton: false,
    });

    useEffect(() => {        
      const getEnviromentVariables = async() => {
        setLoadingEnviromentVariables(true)
        await axios.get('/api/v1/environment-variable').then(res =>{   
          setLoadingEnviromentVariables(false)
          if (res.data.CPD_WIZARD_MODE === "existing-ocp") {
            setCpdWizardMode("existing-ocp")
            setSelection("Configure")
            setCurrentIndex(1)
            //platform will be existing-ocp
          }else if (res.data.CPD_WIZARD_MODE === "deploy") {
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

      <div className="infra-title">Select</div>     
      <RadioButtonGroup orientation="vertical"
         name="radio-button-group" 
         onChange={selectOnChange}
         defaultSelected={selection}  
         valueSelected={selection}         
         >
         <RadioButton labelText="Configure & Deploy" value="Configure+Deploy" id="400" />
         <RadioButton labelText="Configure" value="Configure" id="402" />     
      </RadioButtonGroup>

      </>
    );
  };

export default Selection;