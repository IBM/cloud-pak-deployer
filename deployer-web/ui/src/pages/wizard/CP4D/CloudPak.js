import { AccordionItem, Accordion, Checkbox, FormGroup, Loading, InlineNotification } from 'carbon-components-react';
import { useState, useEffect } from 'react';
import axios from "axios";
import './CloudPak.scss'

const CloudPak = () => {

    const [loadingCPD, setLoadingCPD] = useState(true)
    const [loadCPDErr, setLoadCPDErr] = useState(false)
    const [CPDData, setCPDData] = useState([])

    const [checkParentCheckBox, setCheckParentCheckBox] = useState(false)
    const [indeterminateParentCheckBox, setIndeterminateParentCheckBox] = useState(false)

    useEffect(() => {
       fetchCloudPakData()
    }, [])

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get IBM Cloud Pak Configuration from server.',
      hideCloseButton: false,
    });  

    const fetchCloudPakData =async () => {
        await axios.get('api/v1/cartridges/cp4d').then(res =>{            
            //console.log(res.data)
            setCPDData(res.data)
            updateCheckBox(res.data)
            
        }, err => {
            setLoadCPDErr(true)
            console.log(err)
        });
        setLoadingCPD(false)
    } 

    const updateCheckBox = (data)=> {     
      let totalItems = data.filter(item => item.description != null )      
      let selectedItem = data.filter(item => item.state === "installed")      
      if (totalItems.length === selectedItem.length) {
        setCheckParentCheckBox(true)
      }        
      else {
        if (selectedItem.length >= 0) {
          setIndeterminateParentCheckBox(true)
        }
      }       
    }

    return (
        <>     
          <div className='cpd-container'>
          </div>  

          {loadingCPD && <Loading /> }  
          { loadCPDErr && <InlineNotification className="cpd-error"
                {...errorProps()}        
            /> } 

            <Checkbox className='parent' id="cp4d" labelText="IBM Cloud Pak for Data" disabled checked={checkParentCheckBox} indeterminate={indeterminateParentCheckBox}/>
              { CPDData.map((item, index)=>{
                if (item.description)
                  return (
                    <Checkbox className='child' labelText={item.description} id={item.name} key={index} checked={item.state === "installed"} disabled/>                
                  )          
              }) }             
        </>
    )
}
export default CloudPak;