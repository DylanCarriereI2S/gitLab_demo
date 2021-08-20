// Lambda function code
var AWS = require("aws-sdk");
// Set the AWS Region.
AWS.config.update({ region: "eu-west-1" });

// Create DynamoDB service object.
var docClient = new AWS.DynamoDB.DocumentClient();

module.exports.handler = async (event) => {
    // console.log('Event: ', event);
    let responseMessage = 'Hello, from get todos!';
    let table = process.env.TODO_TABLE
  
    if (event.queryStringParameters && event.queryStringParameters['Name']) {
      responseMessage = 'Hello, ' + event.queryStringParameters['Name'] + '!';
    }

    const params = {
      TableName: table
    };

    res = await docClient.scan(params).promise();

    console.log("Scan : " + JSON.stringify(res.Items));
  
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        todoList: res.Items,
      }),
    }
  }
  