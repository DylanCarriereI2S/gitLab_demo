// Lambda function code
var AWS = require("aws-sdk");
// Set the AWS Region.
AWS.config.update({ region: "eu-west-1" });

// Create DynamoDB service object.
var docClient = new AWS.DynamoDB.DocumentClient();

module.exports.handler = async (event) => {
    console.log('Event: ', event);
    let responseMessage = 'Hello, from delete todo!';
    let table = process.env.TODO_TABLE
  
    if (event.queryStringParameters && event.queryStringParameters['todo']) {

      let todoUuid = event.queryStringParameters['todo'];
      let params = {
        TableName:table,
        Key:{
          "PK":todoUuid
        }
      }

      res = await docClient.delete(params).promise();

    }
  
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods' : '*',
        'Access-Control-Allow-Headers' : '*'
      },
      body: JSON.stringify({
        message: responseMessage,
      }),
    }
  }
  