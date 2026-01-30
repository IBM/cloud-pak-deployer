import axios from "axios";
<<<<<<< HEAD
import { InlineLoading, InlineNotification, Tabs, Tab, CodeSnippet, Button, TextArea } from "@carbon/react";
=======
import { InlineLoading, InlineNotification, Tabs, Tab, CodeSnippet, Button, TextArea } from "carbon-components-react";
>>>>>>> main
import { useEffect, useState } from "react";
import './Summary.scss'
import yaml from 'js-yaml';

<<<<<<< HEAD
const Summary = ({
    configuration,
    setConfiguration,
    summaryLoading,
    setSummaryLoading,
    configDir,
    statusDir,
    tempSummaryInfo,
    setTempSummaryInfo,
    configInvalid,
    setConfigInvalid,
    showErr,
    setShowErr
}) => {


    const [summaryInfo, setSummaryInfo] = useState("")
    const [editable, setEditable] = useState(false)

    const saveSummaryData = async (body) => {
        // console.log('body: ', body)
        configuration.data = body.config
        setConfiguration(configuration)
        setEditable(false)
        setSummaryLoading(false)
    }

    useEffect(() => {
        const formatConfiguration = async () => {
            console.log('Configuration: ',configuration)
            await axios.post('/api/v1/format-configuration', configuration, { headers: { "Content-Type": "application/json" } }).then(res => {
                // console.log('Formatted configuration: ', res)
                setSummaryInfo(res.data.data)
                setTempSummaryInfo(res.data.data)
            }, err => {
                setSummaryLoading(false)
                setShowErr(true)
                console.log(err)
            });
        }

        formatConfiguration()

=======
const Summary = ({cloudPlatform, 
                  IBMCloudSettings, 
                  AWSSettings, 
                  storage, 
                  CPDCartridgesData, 
                  CPICartridgesData, 
                  locked,
                  envId,
                  cp4dLicense,
                  cp4iLicense,
                  cp4dVersion,
                  cp4iVersion,
                  CP4DPlatformCheckBox,
                  CP4IPlatformCheckBox,
                  summaryLoading,
                  setSummaryLoading,
                  configDir,
                  statusDir,
                  tempSummaryInfo,
                  setTempSummaryInfo,
                  configInvalid,
                  setConfigInvalid,
                  showErr,
                  setShowErr
                }) => {

    
    const [summaryInfo, setSummaryInfo] = useState("")      
    const [editable, setEditable] = useState(false)

    const createSummaryData = async () => { 
        let region=""    
        switch (cloudPlatform) {
            case "ibm-cloud":               
                region=IBMCloudSettings.region
                break
            case "aws":                
                region=AWSSettings.region
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
            "cp4dLicense":cp4dLicense,
            "cp4iLicense":cp4iLicense,
            "cp4dVersion":cp4dVersion,
            "cp4iVersion":cp4iVersion,
            "CP4DPlatform":CP4DPlatformCheckBox,
            "CP4IPlatform":CP4IPlatformCheckBox,      
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
            "cp4dLicense":cp4dLicense,
            "cp4iLicense":cp4iLicense,
            "cp4dVersion":cp4dVersion,
            "cp4iVersion":cp4iVersion,
            "CP4DPlatform":CP4DPlatformCheckBox,
            "CP4IPlatform":CP4IPlatformCheckBox,   
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
>>>>>>> main
        // eslint-disable-next-line
    }, []);

    const errorProps = () => ({
        kind: 'error',
        lowContrast: true,
        role: 'error',
        title: 'Failed to save configuration in the server.',
        hideCloseButton: false,
<<<<<<< HEAD
    });

    const clickEditBtn = () => {
        setEditable(true)
    }

    const clickSaveBtn = async () => {
        let body = {}
        let result = {}

        try {
            yaml.loadAll(tempSummaryInfo, function (doc) {
                result = { ...doc, ...result }
            });
            body['config'] = result
            setSummaryInfo(tempSummaryInfo)
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
=======
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
>>>>>>> main
                <InlineNotification className="summary-error"
                    {...errorProps()}
                />
            }

<<<<<<< HEAD
            {configDir &&
                <div className="directory">
                    <div className="item">Configuration Directory:</div>
                    <CodeSnippet type="single">{configDir}</CodeSnippet>
                </div>
            }
            {statusDir &&
                <div className="directory">
                    <div className="item">Status Directory:</div>
                    <CodeSnippet type="single">{statusDir}</CodeSnippet>
                </div>
            }
            <div className="configuration">
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
                        <Button onClick={clickEditBtn} className="wizard-container__page-header-button" disabled={showErr || summaryLoading} >Edit</Button>
                    </div>
                }
                {
                    summaryLoading ? <InlineLoading /> :
                        editable ?
                            <TextArea onChange={textAreaOnChange} className="bx--snippet" type="multi" feedback="Copied to clipboard" rows={20} value={tempSummaryInfo} invalid={configInvalid} invalidText="Invalid yaml formatting." labelText="Configuration (YAML)">
                            </TextArea>
                            :
                            <TextArea className="bx--snippet" type="multi" feedback="Copied to clipboard" rows={20} value={tempSummaryInfo} labelText="Configuration (YAML)" readOnly={true}>
                            </TextArea>
                }
            </div>
        </>
=======
            <div className="directory">
                <div className="item">Configuration Directory:</div>
                <CodeSnippet type="single">{configDir}</CodeSnippet>
            </div>
            <div className="directory">
                <div className="item">Status Directory:</div>
                <CodeSnippet type="single">{statusDir}</CodeSnippet>
            </div>
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
                    <Button onClick={clickEditBtn} className="wizard-container__page-header-button" disabled={showErr || summaryLoading} >Edit</Button> 
                </div>            
            }          

            <div className="configuration">
                <Tabs type="container">
                    <Tab id="configuration" label="Configuration">
                        {
                            summaryLoading ? <InlineLoading />: 
                                editable ? 
                                <TextArea onChange={textAreaOnChange} className="bx--snippet" type="multi" feedback="Copied to clipboard" rows={30} value={tempSummaryInfo} invalid={configInvalid} invalidText="Invalid yaml formatting." labelText="">
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
>>>>>>> main
    )
}

export default Summary;