import axios from "axios";
import { InlineLoading, InlineNotification, CodeSnippet, Button, TextArea } from "@carbon/react";
import { useEffect, useState } from "react";
import './Summary.scss'
import yaml from 'js-yaml';

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
    setShowErr,
    saveConfig,
    setSaveConfig,
    deployerContext
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

        // eslint-disable-next-line
    }, []);

    const errorProps = () => ({
        kind: 'error',
        lowContrast: true,
        role: 'error',
        title: 'Failed to save configuration in the server.',
        hideCloseButton: false,
    });

    const successSaveConfigProps = () => ({
        kind: 'success',
        lowContrast: true,
        role: 'success',
        title: 'The configuration file is saved successfully!',
        hideCloseButton: false,
        onCloseButtonClick: () => setSaveConfig(false),
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
                <InlineNotification className="summary-error"
                    {...errorProps()}
                />
            }
            {saveConfig &&
                <InlineNotification className="summary-success"
                    {...successSaveConfigProps()}
                />
            }

            {configDir && deployerContext !== 'openshift' &&
                <div className="directory">
                    <div className="item">Configuration Directory:</div>
                    <CodeSnippet type="single">{configDir}</CodeSnippet>
                </div>
            }
            {statusDir && deployerContext !== 'openshift' &&
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
    )
}

export default Summary;