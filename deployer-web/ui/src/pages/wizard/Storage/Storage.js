import axios from "axios";
import { Dropdown, InlineNotification, Loading } from "carbon-components-react";
import { useEffect, useState } from "react";
import './Storage.scss'


const Storage = ({cloudPlatform, storagesOptions, setStoragesOptions}) => {

    const [loadingStorage, setLoadingStorage] = useState(true)
    const [loadStorageErr, setLoadStorageErr] = useState(false)

    useEffect(() => {
      fetchStorageData()
    }, [cloudPlatform])
    
    const fetchStorageData =async () => {
      await axios.get('/api/v1/storages/' + cloudPlatform).then(res =>{                 
          setStoragesOptions(res.data)
          setLoadingStorage(false)
      }, err => {
          setLoadStorageErr(true)          
      });
      setLoadingStorage(false)
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
              
          <div className="storage-title">Storage</div> 
          { loadStorageErr && <InlineNotification className="storage-error"
                {...errorProps()}        
            /> } 

          <div style={{ width: 400 }}>
            <Dropdown
              id="default"
              label="Please select the storage class"
              items={storagesOptions}
              itemToString={(item) => (item ? item.storage_name : '')}              
            />
          </div>
        </>        
      )
  };

export default Storage;