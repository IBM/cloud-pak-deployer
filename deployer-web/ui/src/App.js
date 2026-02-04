import './App.css';
import CPDeployerHeader from './components/CPDeployerHeader/CPDeployHeader';
import Wizard from './pages/wizard/Wizard';
import DeployerStatus from './pages/status/DeployerStatus';
import { useState } from "react";
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';

function App() {

  const [headerTitle, setHeaderTitle] = useState("Cloud Pak Deployer")
  return (
    <Router>
      <CPDeployerHeader headerTitle={headerTitle} />
      <Routes>
        <Route path="/" element={
          <Wizard setHeaderTitle={setHeaderTitle}
                  headerTitle={headerTitle}
          />
        } />
        <Route path="/status" element={<DeployerStatus />} />
      </Routes>
    </Router>
  );
}

export default App;
