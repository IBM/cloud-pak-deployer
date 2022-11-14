import axios from "axios";
import { InlineLoading, InlineNotification, Tabs, Tab, CodeSnippet, Button, TextArea } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Summary.scss'
import yaml from 'js-yaml';

const Summary = ({cloudPlatform, IBMCloudSettings, AWSSettings, OCPSettings, storage, CPDCartridgesData, setCPDCartridgesData, CPICartridgesData, setCPICartridgesData}) => {

    const [summaryLoading, setSummaryLoading] = useState(true)
    const [saving, setSaving] = useState(false)

    const [showErr, setShowErr] = useState(false)
    const [summaryInfo, setSummaryInfo] = useState("")  
    const [tempSummaryInfo, setTempSummaryInfo] = useState("") 
    const [configInvalid, setConfigInvalid] = useState(false)  
    
    const [editable, setEditable] = useState(false)

    // const [CPDFullData, setCPDFullData] = useState([])
    // const [CPIFullData, setCPIFullData] = useState([])  
    const [OCPFullData, setOCPFullData] = useState([])  

    const saveFetchSummaryData = async (body) => {           
        // console.log("summary", body)
        await axios.post('/api/v1/loadConfig', body, {headers: {"Content-Type": "application/json"}}).then(res =>{          
            // yaml.loadAll(res.data.cp4d, function (doc) { 
            //     setCPDCartridgesData(doc.cp4d[0].cartridges) 
            //     setCPDFullData(doc.cp4d)
            // }); 
            // yaml.loadAll(res.data.cp4i, function (doc) {  
            //     setCPICartridgesData(doc.cp4i[0].instances)              
            //     setCPIFullData(doc.cp4i)
            // });
            yaml.loadAll(res.data.ocp, function (doc) {    
                setOCPFullData(doc) 
            });
            setSummaryInfo(res.data.ocp + res.data.cp4d + res.data.cp4i)
            setTempSummaryInfo(res.data.ocp + res.data.cp4d + res.data.cp4i)
        }, err => {
            setShowErr(true)
            console.log(err)
        }); 
        setSummaryLoading(false)  
        setSaving(false)     
    }  
    
    const generateBody =()=>{
        let envId = ""
        let region= ""
        let body={}
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
        body = {
            "envId": envId,
            "cloud": cloudPlatform,
            "region": region,
            "storages": storage,
        }       
        return body
    }

    useEffect(() => { 
        let body = generateBody()  
        
        body = {...body,
            "cp4d": CPDCartridgesData,
            "cp4i": CPICartridgesData,
            "ocp": OCPFullData,}
        
        // console.log(body)     
        saveFetchSummaryData(body)
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
        let body = generateBody()
        setSaving(true)
            
        try {                   
            yaml.loadAll(tempSummaryInfo, function (doc) {  

                if (doc.cp4d) {                    
                    body.cp4d = doc
                }
                else if (doc.cp4i) {
                    body.cp4i = doc
                }
                else {
                    body.ocp = doc
                }    
            }); 
            await saveFetchSummaryData(body)

        } catch (error) {
            setConfigInvalid(true)
            console.error(error)
            return
        }        
        setEditable(false)
    }

    const clickCancelBtn = () => {
        setTempSummaryInfo(summaryInfo)
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
                    <Button onClick={clickEditBtn} className="wizard-container__page-header-button">Edit</Button> 
                </div>            
            }          

            <div className="configuration">
                <Tabs type="container">
                    <Tab id="configuration" label="Configuration">
                        {
                            (summaryLoading || saving)? <InlineLoading />: 
                                editable ? 
                                <TextArea onChange={textAreaOnChange} type="multi" feedback="Copied to clipboard" rows={33} value={tempSummaryInfo} invalid={configInvalid} invalidText="Invalid yaml formatting." labelText="Please do not remove three dashes (---), which is used to separate different documents.">
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