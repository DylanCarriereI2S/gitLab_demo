// Lambda function code

module.exports.handler = async (event) => {
    console.log('Event: ', event);
  
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods' : '*',
        'Access-Control-Allow-Headers' : '*'
      }
    }
  }
  