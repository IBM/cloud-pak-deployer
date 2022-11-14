import axios from "axios";
import { Dropdown, InlineNotification, Loading } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Storage.scss'


const Storage = ({cloudPlatform, setStorage, storage, storagesOptions, setStoragesOptions, setWizardError}) => {

    const [loadingStorage, setLoadingStorage] = useState(true)
    const [loadStorageErr, setLoadStorageErr] = useState(false)

    useEffect(() => {
      const fetchStorageData = async () => {
        // if (storagesOptions.length === 0) {
        await axios.get('/api/v1/storages/' + cloudPlatform).then(res =>{                 
          setStoragesOptions(res.data)
          setStorage([res.data[0]])
          setLoadingStorage(false)
          setWizardError(false)
        }, err => {
          setStorage([])
          setStoragesOptions([])
          setLoadStorageErr(true)    
          setWizardError(true)      
        });          
        // }
        setLoadingStorage(false)
        //updateStorageClass()
      }
      fetchStorageData()
      // eslint-disable-next-line
    }, [cloudPlatform])    
    
    const updateStorageClass = (e, storagesOptions) => {
      const selectedStorage = storagesOptions.filter((item)=>(
        item.storage_type === e.selectedItem.storage_type
      ))
      setStorage(selectedStorage)    
    }

    const errorProps = () => ({
      kind: 'error',
      lowContrast: true,
      role: 'error',
      title: 'Unable to get storage class from server.',
      hideCloseButton: false,
    });  
    return (
        <> 
          {loadingStorage && <Loading /> }    

          { loadStorageErr && <InlineNotification className="storage-error"
                {...errorProps()}        
            /> }                
          <div className="storage-title">Storage</div> 
          <div style={{ width: 400 }}>
            <Dropdown
              id="default"
              label="Please select the storage class"
              items={storagesOptions}
              itemToString={(item) => (item.storage_type )}  
              onChange={(e)=>updateStorageClass(e, storagesOptions)}     
              selectedItem={storage.length === 1 ? storage[0] : storagesOptions[0]}     
            />
          </div>
        </>        
      )
  };

export default Storage;