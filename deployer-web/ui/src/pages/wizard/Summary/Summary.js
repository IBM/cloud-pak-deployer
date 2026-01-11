import axios from "axios";
import { InlineLoading, InlineNotification, Tabs, Tab, CodeSnippet, Button, TextArea } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Summary.scss'
import yaml from 'js-yaml';

const Summary = ({ 
    configuration,
    setConfiguration,
    locked,
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

    const updateSummaryData = async () => {
        let body = {
            "configuration":configuration
        }

        console.log('body: ', body)

        await axios.put('/api/v1/configuration', body, {headers: {"Content-Type": "application/json"}}).then(res =>{   
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
        console.log('body: ', body)
        configuration.data = body.config
        setConfiguration(configuration)
        setEditable(false)
        setSummaryLoading(false)        
    }     

    useEffect(() => {        
        if (locked) {
            setSummaryLoading(true) 
            updateSummaryData()
        } 
        // eslint-disable-next-line
    }, []);

    const errorProps = () => ({
        kind: 'error',
        lowContrast: true,
        role: 'error',
        title: 'Failed to save configuration in the server.',
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
                <InlineNotification className="summary-error"
                    {...errorProps()}        
                />           
            }

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
    )
}

export default Summary;