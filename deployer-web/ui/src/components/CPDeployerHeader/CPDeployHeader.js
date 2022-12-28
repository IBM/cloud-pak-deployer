import React from 'react';
import {
  Header,
  HeaderName,  
  HeaderGlobalBar,
} from 'carbon-components-react';

let headerTitle = process.env.REACT_APP_CPD_WIZARD_PAGE_TITLE  || "Cloud Pak Deployer"

const CPDeployerHeader = () => (
  <Header aria-label="Cloud Pak Deployer">
    <HeaderName href="/" prefix="">
    {headerTitle}
    </HeaderName>        
    <HeaderGlobalBar />
  </Header>
);

export default CPDeployerHeader;