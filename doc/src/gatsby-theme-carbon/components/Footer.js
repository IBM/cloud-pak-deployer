import React from 'react';
import Footer from 'gatsby-theme-carbon/src/components/Footer';

const Content = ({ buildTime }) => (
  <>
    <p> </p>
  </>
);

const links = {
  firstCol: [
    { },
  ],
  /* secondCol: [
    { href: 'https://ibm.com/design', linkText: 'Shadowed link' },
    { href: 'https://ibm.com/design', linkText: 'Shadowed link' },
    { href: 'https://ibm.com/design', linkText: 'Shadowed link' },
    { href: 'https://ibm.com/design', linkText: 'Shadowed link' },
  ],*/
};

const CustomFooter = () => <Footer links={links} Content={Content} />;

export default CustomFooter;
