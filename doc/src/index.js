import ApolloClient from 'apollo-boost';
import { ApolloProvider } from 'react-apollo';


const client = new ApolloClient({
  uri: 'https://api.github.com/graphql',
  headers: {
    authorization: `Bearer ${process.env.REACT_APP_GITHUB_PERSONAL_ACCESS_TOKEN}`,
  },
});


<ApolloProvider client={client}>
  <Router>
    <App />
  </Router>
</ApolloProvider>


