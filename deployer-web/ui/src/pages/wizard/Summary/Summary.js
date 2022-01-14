import axios from "axios";
import { Accordion, AccordionItem, InlineLoading, TextArea, InlineNotification } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Summary.scss'

const Summary = ({envId, cloud}) => {

    const [loading, setLoading] = useState(false)
    const [showErr, setShowErr] = useState(false)
    const [summaryInfo, setSummaryInfo] = useState({})    

    useEffect(() => {
        fetchData()
    }, []);

    const fetchData = () => {
        setLoading(true)
        let body = {
            "envId": envId,
            "cloud": cloud,
        }
        axios.post('/api/v1/loadConifg', body, {headers: {"Content-Type": "application/json"}}).then(res =>{           
            setSummaryInfo(res.data)
            setLoading(false)
        }, err => {
            setShowErr(true)
            console.log(err)
        });
    }

    const onCloseButtonClick = () => {
        setShowErr(false)
    }

    const errorProps = () => ({
        kind: 'error',
        lowContrast: true,
        role: 'error',
        title: 'Unable to load deployment configuration from server.',
        hideCloseButton: false,
        //onClose:'onClose',
        onCloseButtonClick: onCloseButtonClick,
    });    

    return (      
        <>     
        <div className="summary-title">Summary</div> 
            {showErr &&           
                <InlineNotification className="summary-error"
                    {...errorProps()}        
                />           
            }
            <Accordion>
                <AccordionItem title="Openshift Configuration">
                {
                    loading ? <InlineLoading />:
                    <TextArea
                        rows={30}
                        className="summary-config-item"
                        hideLabel={true}
                        placeholder={summaryInfo.envId}   
                        labelText=""                    
                    />
                }
                </AccordionItem>
                <AccordionItem title="IBM Cloud Pak Configuration">
                {
                    loading ? <InlineLoading />:
                    <TextArea
                        rows={30}
                        className="summary-config-item"
                        hideLabel={true}
                        placeholder={summaryInfo.cp4d}  
                        labelText=""                       
                    />
                }               
                </AccordionItem>              
            </Accordion>             
        </>        
    )
}

export default Summary;