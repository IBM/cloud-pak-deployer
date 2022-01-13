import './App.css';
import CPDeployerHeader from './components/CPDeployerHeader/CPDeployHeader';
import Wizard from './pages/wizard/Wizard';
import {
  Button,
  ProgressIndicator,
  ProgressStep,
  Breadcrumb,
  BreadcrumbItem,
  InlineNotification,
} from 'carbon-components-react';

function App() {
  return (
    <>
    <CPDeployerHeader />   
    <Wizard />   
    </>
  );
}

export default App;
