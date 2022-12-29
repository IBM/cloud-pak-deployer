import React from 'react';
import {
  Header,
  HeaderName,  
  HeaderGlobalBar,
} from 'carbon-components-react';

const CPDeployerHeader = ({headerTitle}) => {

  return (
    <Header aria-label={headerTitle}>
      <HeaderName href="/" prefix="">
        {headerTitle}
      </HeaderName>        
      <HeaderGlobalBar />
    </Header>
  )
}

export default CPDeployerHeader;