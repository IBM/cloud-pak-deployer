module.exports = {
  siteMetadata: {
    title: 'Cloud Pak Deployer',
    description: 'Automated deployment of OpenShift and Cloud Paks',
    keywords: 'gatsby,theme,carbon',
  },
  pathPrefix: "/cloud-pak-deployer",
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
            'https://github.com/IBM/cloud-pak-deployer.git',
          subDirectory: '',
          branch: 'main',
        },
      },
    },
  ],
};
