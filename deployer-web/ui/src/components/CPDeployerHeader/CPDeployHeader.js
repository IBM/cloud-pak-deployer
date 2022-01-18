import React from 'react';
import {
  Header,
  HeaderName,  
  HeaderGlobalBar,
} from 'carbon-components-react';

const CPDeployerHeader = () => (
  <Header aria-label="Cloud Pak Deployer">
    <HeaderName href="/">
    Cloud Pak Deployer
    </HeaderName>        
    <HeaderGlobalBar />
  </Header>
);

export default CPDeployerHeader;