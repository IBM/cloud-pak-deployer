import axios from "axios";
import { InlineLoading, InlineNotification, Tabs, Tab, CodeSnippet, Button, TextArea } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Summary.scss'
import yaml from 'js-yaml';

const Summary = ({cloudPlatform, 
                  IBMCloudSettings, 
                  AWSSettings, 
                  OCPSettings, 
                  storage, 
                  CPDCartridgesData, 
                  CPICartridgesData, 
                  locked,
                }) => {

    const [summaryLoading, setSummaryLoading] = useState(false)
  
    const [showErr, setShowErr] = useState(false)
    const [summaryInfo, setSummaryInfo] = useState("")  
    const [tempSummaryInfo, setTempSummaryInfo] = useState("") 
    const [configInvalid, setConfigInvalid] = useState(false)  
    
    const [editable, setEditable] = useState(false)

    const createSummaryData = async () => {    
        let envId=""
        let region=""    
        switch (cloudPlatform) {
            case "ibm-cloud":
                envId=IBMCloudSettings.envId
                region=IBMCloudSettings.region
                break
            case "aws":
                envId=AWSSettings.envId
                region=AWSSettings.region
                break
            case "existing-ocp":
                envId=OCPSettings.envId
                break
            default:
        }  
        let body = {
            "envId": envId,
            "cloud": cloudPlatform,
            "region": region,
            "storages": storage,
            "cp4d": CPDCartridgesData,
            "cp4i": CPICartridgesData,
        }     

        await axios.post('/api/v1/createConfig', body, {headers: {"Content-Type": "application/json"}}).then(res =>{  
            setSummaryLoading(false)          
            setSummaryInfo(res.data.config)
            setTempSummaryInfo(res.data.config)
        }, err => {
            setSummaryLoading(false)  
            setShowErr(true)
            console.log(err)
        }); 
           
    } 
    
    const updateSummaryData = async () => {  
        let body = {
            "cp4d": CPDCartridgesData,
            "cp4i": CPICartridgesData,
        }  
        await axios.put('/api/v1/updateConfig', body, {headers: {"Content-Type": "application/json"}}).then(res =>{   
            setSummaryLoading(false)        
            setSummaryInfo(res.data.config)
            setTempSummaryInfo(res.data.config)
        }, err => {
            setSummaryLoading(false) 
            setShowErr(true)
            console.log(err)
        });          
    }

    const saveSummaryData = async (body) => {         
        await axios.post('/api/v1/saveConfig', body, {headers: {"Content-Type": "application/json"}}).then(res =>{   
            setEditable(false)
            setSummaryLoading(false)        
            setSummaryInfo(res.data.config)
            setTempSummaryInfo(res.data.config)
        }, err => {
            setSummaryLoading(false) 
            setShowErr(true)
            console.log(err)
        });          
    }     

    useEffect(() => {        
        if (locked) {
            setSummaryLoading(true) 
            updateSummaryData()
        } 
        else {
            setSummaryLoading(true)  
            createSummaryData()
        }        
        // eslint-disable-next-line
    }, []);

    const errorProps = () => ({
        kind: 'error',
        lowContrast: true,
        role: 'error',
        title: 'Unable to load deployment configuration from server.',
        hideCloseButton: false,
    });  
    
    const clickEditBtn = () => {
        setEditable(true)
    }

    const clickSaveBtn = async() => { 
        let body = {}
        let result = {}
            
        try {                   
            yaml.loadAll(tempSummaryInfo, function (doc) {
                result = {...doc, ...result}
            }); 
            body['config'] = result
            setSummaryLoading(true)      
            await saveSummaryData(body)

        } catch (error) {
            setConfigInvalid(true)
            console.error(error)
            return
        }        
    }

    const clickCancelBtn = () => {
        setTempSummaryInfo(summaryInfo)
        setConfigInvalid(false)
        setEditable(false)
    }

    const textAreaOnChange = (e) => {
        setTempSummaryInfo(e.target.value)
    }

    return (      
        <>     
            <div className="summary-title">Summary</div> 
            {showErr &&           
                <InlineNotification className="summary-error"
                    {...errorProps()}        
                />           
            }
            {editable ? 
                <div className="flex-right">
                    <div >
                        <Button onClick={clickCancelBtn} className="wizard-container__page-header-button">Cancel</Button> 
                    </div>
                    <div>
                        <Button onClick={clickSaveBtn} className="wizard-container__page-header-button">Save</Button> 
                    </div>
                </div>
                :
                <div className="align-right">
                    <Button onClick={clickEditBtn} className="wizard-container__page-header-button" disabled={showErr} >Edit</Button> 
                </div>            
            }          

            <div className="configuration">
                <Tabs type="container">
                    <Tab id="configuration" label="Configuration">
                        {
                            summaryLoading ? <InlineLoading />: 
                                editable ? 
                                <TextArea onChange={textAreaOnChange} type="multi" feedback="Copied to clipboard" rows={30} value={tempSummaryInfo} invalid={configInvalid} invalidText="Invalid yaml formatting." labelText="Please do not remove three dashes (---), which is used to separate different documents.">
                                </TextArea>
                                :
                                <CodeSnippet type="multi" feedback="Copied to clipboard" maxCollapsedNumberOfRows={40}>
                                    {summaryInfo}                                   
                                </CodeSnippet>                                                    
                        }    
                    </Tab>
                </Tabs>
            </div>      
        </>        
    )
}

export default Summary;