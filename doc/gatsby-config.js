module.exports = {
  siteMetadata: {
    title: 'Cloud Pak Deployer',
    description: 'Automated deployment of OpenShift and Cloud Paks',
    keywords: 'gatsby,theme,carbon',
  },
  pathPrefix: "/CloudPakDeployer/cloud-pak-deployer",
  plugins: [
    {
      resolve: 'gatsby-plugin-manifest',
      options: {
        name: 'Carbon Design Gatsby Theme',
        short_name: 'Gatsby Theme Carbon',
        start_url: '/',
        background_color: '#ffffff',
        theme_color: '#0062ff',
        display: 'browser',
        icon: "src/images/dummy.png",
      }
    },
    {
      resolve: 'gatsby-theme-carbon',
      options: {
        mediumAccount: 'carbondesign',
        repository: {
          baseUrl:
            'https://github.ibm.com/CloudPakDeployer/cloud-pak-deployer',
          subDirectory: '',
          branch: 'main',
        },
      },
    },
  ],
};
