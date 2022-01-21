import axios from "axios";
import { InlineLoading, InlineNotification, Tabs, Tab, CodeSnippet } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Summary.scss'

const Summary = ({envId, cloudPlatform, storage, region, CPDData}) => {

    const [summaryLoading, setSummaryLoading] = useState(true)
    const [showErr, setShowErr] = useState(false)
    const [summaryInfo, setSummaryInfo] = useState({})      

    useEffect(() => {
        const fetchSummaryData = async () => {            
            let body = {
                "envId": envId,
                "cloud": cloudPlatform,
                "cartridges": CPDData,
                "region": region,
                "storages": storage,
            }
            //console.log("summary", body)
            await axios.post('/api/v1/loadConfig', body, {headers: {"Content-Type": "application/json"}}).then(res =>{       
                setSummaryInfo(res.data)
                setSummaryLoading(false)
            }, err => {
                setShowErr(true)
                console.log(err)
            });        
        }        
        fetchSummaryData()
    }, []);

    const errorProps = () => ({
        kind: 'error',
        lowContrast: true,
        role: 'error',
        title: 'Unable to load deployment configuration from server.',
        hideCloseButton: false,
    });    

    return (      
        <>     
        <div className="summary-title">Summary</div> 
            {showErr &&           
                <InlineNotification className="summary-error"
                    {...errorProps()}        
                />           
            }
            {/* <Accordion>
                <AccordionItem title="Openshift Configuration">
                {
                    summaryLoading ? <InlineLoading />:
                    <TextArea
                        rows={30}
                        className="summary-config-item"
                        hideLabel={true}
                        placeholder={summaryInfo.envId}   
                        labelText=""   
                        disabled                 
                    />
                }
                </AccordionItem>
                <AccordionItem title="IBM Cloud Pak Configuration">
                {
                    summaryLoading ? <InlineLoading />:
                    <TextArea
                        rows={30}
                        className="summary-config-item"
                        hideLabel={true}
                        placeholder={summaryInfo.envId}   
                        labelText=""   
                        disabled                 
                    />
                }            
                </AccordionItem>              
            </Accordion>  */}
            <Tabs type="container">
                <Tab id="openshift" label="Openshift Configuration">
                {
                    summaryLoading ? <InlineLoading />:
                    <CodeSnippet type="multi" feedback="Copied to clipboard">
                    {summaryInfo.envId}  
                    </CodeSnippet>
                }    
                </Tab>
                <Tab id="cp4d" label="IBM Cloud Pak Configuration">
                {
                    summaryLoading ? <InlineLoading />:
                    <CodeSnippet type="multi" feedback="Copied to clipboard">
                        {summaryInfo.cp4d}  
                    </CodeSnippet>
                 }                 
                </Tab>     
          </Tabs>           
        </>        
    )
}

export default Summary;