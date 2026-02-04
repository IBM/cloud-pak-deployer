import React, { useState, useEffect } from 'react';
import './DeployerStatus.scss';
import { ProgressBar, Button, InlineNotification, RadioButtonGroup, RadioButton, Table, TableHead, TableRow, TableBody, TableCell, TableHeader } from '@carbon/react';
import axios from 'axios';
import fileDownload from 'js-file-download';

const DeployerStatus = () => {
  const [deployerStatus, setDeployerStatus] = useState(true);
  const [deployerPercentageCompleted, setDeployerPercentageCompleted] = useState(0);
  const [deployerStage, setDeployerStage] = useState('');
  const [deployerLastStep, setDeployerLastStep] = useState('');
  const [deployerCompletionState, setDeployerCompletionState] = useState('');
  const [deployerCurrentImage, setDeployerCurrentImage] = useState('');
  const [deployerImageNumber, setDeployerImageNumber] = useState('');
  const [scheduledJob, setScheduledJob] = useState(0);
  const [deployeyLog, setdeployeyLog] = useState('deployer-log');
  const [deployState, setDeployState] = useState([]);
  const [deployerContext, setDeployerContext] = useState('local');
  const [deletingJob, setDeletingJob] = useState(false);
  const [deleteJobSuccess, setDeleteJobSuccess] = useState(false);
  const [deleteJobError, setDeleteJobError] = useState('');

  const getDeployStatus = async () => {
    await axios.get('/api/v1/deployer-status').then(res => {
      setDeployerStatus(res.data.deployer_active);
      if (res.data.deployer_active) {
        setDeployerPercentageCompleted(res.data.percentage_completed);
      } else {
        setDeployerPercentageCompleted(100);
      }

      if (res.data.deployer_stage) {
        setDeployerStage(res.data.deployer_stage);
      } else {
        setDeployerStage("");
      }
      if (res.data.last_step) {
        setDeployerLastStep(res.data.last_step);
      } else {
        setDeployerLastStep("");
      }
      if (res.data.service_state) {
        setDeployState(res.data.service_state);
      }
      if (res.data.completion_state) {
        setDeployerCompletionState(res.data.completion_state);
      }
      if (res.data.mirror_current_image) {
        setDeployerCurrentImage(res.data.mirror_current_image);
      }
      if (res.data.mirror_number_images) {
        setDeployerImageNumber(res.data.mirror_number_images);
      }
    }, err => {
      console.log(err);
    });
  };

  const refreshStatus = () => {
    setScheduledJob(setInterval(() => {
      getDeployStatus();
    }, 5000));
  };

  const deleteDeployerJob = async () => {
    if (deployerContext !== 'openshift') {
      setDeleteJobError('Delete operation is only available for OpenShift deployments');
      return;
    }

    if (!window.confirm('Are you sure you want to delete the cloud-pak-deployer job? This will stop the current deployment.')) {
      return;
    }

    setDeletingJob(true);
    setDeleteJobError('');
    setDeleteJobSuccess(false);

    try {
      await axios.delete('/api/v1/delete-deployer-job').then(res => {
        setDeletingJob(false);
        setDeleteJobSuccess(true);
        setDeleteJobError('');
        setTimeout(() => {
          getDeployStatus();
          setDeleteJobSuccess(false);
        }, 2000);
      }, err => {
        setDeletingJob(false);
        setDeleteJobSuccess(false);
        const errorMsg = err.response?.data?.message || 'Failed to delete deployer job';
        setDeleteJobError(errorMsg);
        console.log(err);
      });
    } catch (error) {
      setDeletingJob(false);
      setDeleteJobSuccess(false);
      setDeleteJobError('An error occurred while deleting the job');
      console.log(error);
    }
  };

  const downloadLog = async () => {
    const body = { "deployerLog": deployeyLog };
    const headers = { 'Content-Type': 'application/json; application/octet-stream', responseType: 'blob' };
    await axios.post('/api/v1/download-log', body, headers).then(res => {
      if (deployeyLog === 'all-logs') {
        fileDownload(res.data, "cloud-pak-deployer-logs.tar.gz");
      } else {
        fileDownload(res.data, "cloud-pak-deployer.log");
      }
    }, err => {
      console.log(err);
    });
  };

  useEffect(() => {
    const getEnviromentVariables = async () => {
      await axios.get('/api/v1/environment-variable').then(async res => {
        if (res.data.CPD_CONTEXT) {
          setDeployerContext(res.data.CPD_CONTEXT);
        }
      }, err => {
        console.log(err);
      });
    };

    getEnviromentVariables();
    getDeployStatus();
    refreshStatus();

    return () => {
      clearInterval(scheduledJob);
    };
    // eslint-disable-next-line
  }, []);

  useEffect(() => {
    if (!deployerStatus) {
      clearInterval(scheduledJob);
    }
    return () => {
      clearInterval(scheduledJob);
    };
    // eslint-disable-next-line
  }, [deployerStatus]);

  const oneDimensionArray2twoDimensionArray = (baseArray) => {
    let len = baseArray.length;
    let n = 9;
    let lineNum = len % n === 0 ? len / n : Math.floor((len / n) + 1);
    let res = [];
    for (let i = 0; i < lineNum; i++) {
      let temp = baseArray.slice(i * n, i * n + n);
      res.push(temp);
    }
    return res;
  };

  const headers = ['Service', 'State'];
  const tables = oneDimensionArray2twoDimensionArray(deployState);

  return (
    <div className="wizard-container">
      <div className="wizard-container__page">
        <div className='wizard-container__page-header'>
          <div className='wizard-container__page-header-title'>
            <h2>Deployer Status</h2>
            <div className='wizard-container__page-header-subtitle'>IBM Cloud Pak Deployment</div>
          </div>
        </div>

        <div className="deploy-stats-container">
          <div className="deploy-stats-left">
            <div className="deploy-status">Deployer Status:</div>

            {!deployerStatus && <div className="deploy-key">
              <div>Completion state:</div>
              <div className="deploy-value">{deployerCompletionState}</div>
            </div>}

            <div className="deploy-key">
              <div>State:</div>
              <div className="deploy-value">{deployerStatus ? 'ACTIVE' : 'INACTIVE'}</div>
            </div>

            {deployerStage && <div className="deploy-key">
              <div>Current Stage:</div>
              <div className="deploy-value">{deployerStage}</div>
            </div>}

            {deployerLastStep && <div className="deploy-key">
              <div>Current Task:</div>
              <div className="deploy-value">{deployerLastStep}</div>
            </div>}

            {deployerCurrentImage && <div className="deploy-key">
              <div>Current Image:</div>
              <div className="deploy-value">{deployerCurrentImage}</div>
            </div>}

            {deployerImageNumber && <div className="deploy-key">
              <div>Mirror Images Number:</div>
              <div className="deploy-value">{deployerImageNumber}</div>
            </div>}

            <div className="deploy-key">
              <div>Deployer Log:</div>
              <div className="deploy-value">
                <RadioButtonGroup
                  onChange={(value) => { setdeployeyLog(value); }}
                  legendText=""
                  name="log-options-group"
                  defaultSelected={deployeyLog}>
                  <RadioButton
                    labelText="Deployer log"
                    value="deployer-log"
                    id="log-radio-1"
                  />
                  <RadioButton
                    labelText="All logs"
                    value="all-logs"
                    id="log-radio-2"
                  />
                </RadioButtonGroup>
              </div>
            </div>

            <div className="deploy-key">
              <Button onClick={downloadLog}>Download logs</Button>
            </div>

            <div className="deploy-item">Deployer Progress:
              <ProgressBar
                label=""
                helperText=""
                value={deployerPercentageCompleted}
              />
            </div>
          </div>

          <div className="deploy-stats-right">
            {deployerContext === 'openshift' && (
              <div className="deploy-stop-button-container">
                <Button
                  kind="danger"
                  onClick={deleteDeployerJob}
                  disabled={deletingJob}
                >
                  {deletingJob ? 'Deleting...' : 'Stop Deployer job'}
                </Button>
              </div>
            )}

            {deleteJobSuccess && (
              <InlineNotification
                kind="success"
                title="Success"
                subtitle="Deployer job deleted successfully"
                onCloseButtonClick={() => setDeleteJobSuccess(false)}
              />
            )}

            {deleteJobError && (
              <InlineNotification
                kind="error"
                title="Error"
                subtitle={deleteJobError}
                onCloseButtonClick={() => setDeleteJobError('')}
              />
            )}
          </div>
        </div>

        <div>
          {deployState.length > 0 &&
            <div className="deploy-item">Status of services:
              <div className="deploy-item__state">
                {tables.map((table, index) => (
                  <div className="deploy-item__state-table" key={index}>
                    <Table size="md" useZebraStyles={false}>
                      <TableHead>
                        <TableRow>
                          {headers.map((header) => (
                            <TableHeader id={header.key} key={header}>
                              {header}
                            </TableHeader>
                          ))}
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {table.map((row) => (
                          <TableRow key={row.id}>
                            {Object.keys(row)
                              .filter((key) => key !== 'id')
                              .map((key) => {
                                return <TableCell key={key}>{row[key]}</TableCell>;
                              })}
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                ))}
              </div>
            </div>
          }
        </div>
      </div>
    </div>
  );
};

export default DeployerStatus;