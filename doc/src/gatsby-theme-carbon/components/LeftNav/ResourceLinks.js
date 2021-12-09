import React from 'react';
import ResourceLinks from 'gatsby-theme-carbon/src/components/LeftNav/ResourceLinks';

const links = [
  {
    title: 'Cloud Pak Deployer GitHub',
    href: 'https://github.ibm.com/CloudPakDeployer/cloud-pak-deployer',
  },
  {
    title: 'Carbon',
    href: 'https://www.carbondesignsystem.com',
  },
  {
    title: 'Gatsby Guide',
    href: 'https://gatsby-theme-carbon.now.sh/getting-started',
  }
];

// shouldOpenNewTabs: true if outbound links should open in a new tab
const CustomResources = () => <ResourceLinks shouldOpenNewTabs links={links} />;

export default CustomResources;
