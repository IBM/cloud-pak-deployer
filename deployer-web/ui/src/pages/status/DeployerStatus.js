import React, { useState, useEffect } from 'react';
import './DeployerStatus.scss';
import { ProgressBar, Button, InlineNotification, RadioButtonGroup, RadioButton, Table, TableHead, TableRow, TableBody, TableCell, TableHeader } from '@carbon/react';
import { View, ViewOff, Copy } from '@carbon/icons-react';
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
  const [cp4dUrl, setCp4dUrl] = useState('');
  const [cp4dUser, setCp4dUser] = useState('');
  const [cp4dPassword, setCp4dPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [copiedField, setCopiedField] = useState('');

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
      if (res.data.cp4d_url) {
        setCp4dUrl(res.data.cp4d_url);
      } else {
        setCp4dUrl("");
      }
      if (res.data.cp4d_user) {
        setCp4dUser(res.data.cp4d_user);
      } else {
        setCp4dUser("");
      }
      if (res.data.cp4d_password) {
        setCp4dPassword(res.data.cp4d_password);
      } else {
        setCp4dPassword("");
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

  const copyToClipboard = async (text, fieldName) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedField(fieldName);
      setTimeout(() => setCopiedField(''), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
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
          <div>
            {deployerContext === 'openshift' && deployerStatus && (
              <Button
                className="wizard-container__page-header-button"
                kind="danger"
                onClick={deleteDeployerJob}
                disabled={deletingJob}
                style={{ width: '12rem', whiteSpace: 'nowrap' }}
              >
                {deletingJob ? 'Deleting...' : 'Stop Deployer job'}
              </Button>
            )}
          </div>
        </div>

        {deleteJobSuccess && (
          <InlineNotification
            kind="success"
            title="Success"
            subtitle="Deployer job deleted successfully"
            onCloseButtonClick={() => setDeleteJobSuccess(false)}
            style={{ marginTop: '1rem' }}
          />
        )}

        {deleteJobError && (
          <InlineNotification
            kind="error"
            title="Error"
            subtitle={deleteJobError}
            onCloseButtonClick={() => setDeleteJobError('')}
            style={{ marginTop: '1rem' }}
          />
        )}

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
            {!deployerStatus && cp4dUrl && <div className="deploy-key" style={{ alignItems: 'center' }}>
              <div>Software Hub URL:</div>
              <div className="deploy-value" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <a href={cp4dUrl} target="_blank" rel="noopener noreferrer">{cp4dUrl}</a>
                <Button
                  kind="ghost"
                  size="sm"
                  hasIconOnly
                  renderIcon={Copy}
                  iconDescription={copiedField === 'url' ? 'Copied!' : 'Copy URL'}
                  onClick={() => copyToClipboard(cp4dUrl, 'url')}
                  style={{ minHeight: '32px' }}
                />
              </div>
            </div>}

            {cp4dUser && <div className="deploy-key" style={{ alignItems: 'center' }}>
              <div>Software Hub admin user:</div>
              <div className="deploy-value" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span>{cp4dUser}</span>
                <Button
                  kind="ghost"
                  size="sm"
                  hasIconOnly
                  renderIcon={Copy}
                  iconDescription={copiedField === 'user' ? 'Copied!' : 'Copy user'}
                  onClick={() => copyToClipboard(cp4dUser, 'user')}
                  style={{ minHeight: '32px' }}
                />
              </div>
            </div>}

            {cp4dPassword && <div className="deploy-key" style={{ alignItems: 'center' }}>
              <div>Software Hub password:</div>
              <div className="deploy-value" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ fontFamily: showPassword ? 'inherit' : 'monospace' }}>
                  {showPassword ? cp4dPassword : '••••••••••••'}
                </span>
                <Button
                  kind="ghost"
                  size="sm"
                  hasIconOnly
                  renderIcon={showPassword ? ViewOff : View}
                  iconDescription={showPassword ? 'Hide password' : 'Show password'}
                  onClick={() => setShowPassword(!showPassword)}
                  style={{ minHeight: '32px' }}
                />
                <Button
                  kind="ghost"
                  size="sm"
                  hasIconOnly
                  renderIcon={Copy}
                  iconDescription={copiedField === 'password' ? 'Copied!' : 'Copy password'}
                  onClick={() => copyToClipboard(cp4dPassword, 'password')}
                  style={{ minHeight: '32px' }}
                />
              </div>
            </div>}

            {deployState.length > 0 && (
              <div style={{ marginTop: '2rem', width: '100%', alignSelf: 'flex-start' }}>
                <div style={{ fontWeight: 'bold', marginBottom: '1rem', fontSize: '1rem' }}>Status of services:</div>
                <div style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '1rem',
                  width: '100%',
                  maxHeight: deployState.length > 10 ? '500px' : 'none',
                  overflowY: deployState.length > 10 ? 'auto' : 'visible',
                  paddingRight: deployState.length > 10 ? '0.5rem' : '0'
                }}>
                  {tables.map((table, index) => (
                    <div key={index} style={{ width: '600px', maxWidth: '100%' }}>
                      <Table size="sm" useZebraStyles={false}>
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
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default DeployerStatus;