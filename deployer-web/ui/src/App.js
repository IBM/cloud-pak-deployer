import './App.css';
import CPDeployerHeader from './components/CPDeployerHeader/CPDeployHeader';
import Wizard from './pages/wizard/Wizard';
import { useState } from "react";

function App() {

  const [headerTitle, setHeaderTitle] = useState("Cloud Pak Deployer")
  return (
    <>
      <CPDeployerHeader headerTitle={headerTitle} />   
      <Wizard setHeaderTitle={setHeaderTitle}
              headerTitle={headerTitle}      
      />   
    </>
  );
}

export default App;
