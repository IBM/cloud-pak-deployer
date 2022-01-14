import { AccordionItem, Accordion, Checkbox } from 'carbon-components-react';
import './CloudPak.scss'

const CloudPak = () => {
    return (
        <>     
            <div className='cpd-container'>
            </div>   
            <Accordion>
                <AccordionItem title="IBM Cloud Pak for Data" className='cpd-container__items-title'>
                <fieldset className="cpd-container__items-cartridges">
                    <legend className="cpd-container__items-cartridges-title">Cartridges</legend>
                    <Checkbox labelText='Db2' id="0"/>
                    <Checkbox labelText='Db2 Data Gate' id="1"/>
                    <Checkbox labelText='Db2 Data Management Console' id="2"/>
                    <Checkbox labelText='Db2 Event Store' id="3"/>
                </fieldset>
               
                </AccordionItem>             
            </Accordion>   
        </>
    )
}
export default CloudPak;