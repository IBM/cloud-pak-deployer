import axios from "axios";
import { Accordion, AccordionItem, InlineLoading, TextArea } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Summary.scss'

const Summary = () => {

    const [loading, setLoading] = useState(false)
    let summaryResult = useState(true)
    useEffect(() => {
        fetchDate()
    }, []);

    const fetchDate = () => {
        setLoading(true)
        let body = {
            "envId":"ibm-cloud",
            "configDir":"/tmp/config",
        }
        axios.post('/api/v1/loadConifg', body, {headers: {"Content-Type": "application/json"}}).then(res =>{
            console.log(res)
            summaryResult = res.data
            console.log(summaryResult)
            setLoading(false)
        }, err => {
            setLoading(false)
        });
    }

    return (
        <>
            
            <div className="summary-title">Summary</div>  
            <Accordion>
                <AccordionItem title="CPD configuration">
                {
                    loading ? <InlineLoading />:
                    <TextArea
                    hideLabel={true}
                    placeholder={summaryResult.cp4d}
                    className="TEST_CLASS"
                    />
                }
                </AccordionItem>
                <AccordionItem title="IBM Cloud Pak configuration">
                {
                    loading ? <InlineLoading />:
                    <TextArea
                    hideLabel={true}
                    placeholder={summaryResult.envId}
                    className="TEST_CLASS"
                    />
                }
                </AccordionItem>              
            </Accordion> 

            
        </>        
    )
}

export default Summary;