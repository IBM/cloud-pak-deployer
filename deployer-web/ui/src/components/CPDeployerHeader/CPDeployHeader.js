import React from 'react';
import {
  Header,
  HeaderName,  
  HeaderGlobalBar,
} from 'carbon-components-react';

const CPDeployerHeader = () => (
  <Header aria-label="Cloud Pak Deployer">
    <HeaderName href="https://pages.github.ibm.com/CloudPakDeployer/cloud-pak-deployer/">
    Cloud Pak Deployer
    </HeaderName>        
    <HeaderGlobalBar />
  </Header>
);

export default CPDeployerHeader;