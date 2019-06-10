namespace FilterModule
{
    using Microsoft.Azure.Devices.Client;
    using Microsoft.Azure.Devices.Client.Transport.Mqtt;
    using Microsoft.Azure.Devices.Shared;
    using Newtonsoft.Json;
    using System;
    using System.Collections.Generic;
    using System.Runtime.Loader;
    using System.Text;
    using System.Threading;
    using System.Threading.Tasks;

    public class MessageBody
    {
        public Machine machine {get;set;}
        public Ambient ambient {get; set;}
        public string timeCreated {get; set;}
    }

    public class Machine
    {
        public double temperature {get; set;}
        public double pressure {get; set;}         
    }

    public class Ambient
    {
        public double temperature {get; set;}
        public int humidity {get; set;}         
    }

    public class Program
    {
        private const string healthCheck = "healthcheck";
        private static int counter;
        private static ModuleClient ioTHubModuleClient;
        private static int temperatureThreshold = 25;

        static void Main(string[] args)
        {
            Init().Wait();

            // Wait until the app unloads or is cancelled
            var cts = new CancellationTokenSource();
            AssemblyLoadContext.Default.Unloading += (ctx) => cts.Cancel();
            Console.CancelKeyPress += (sender, cpe) => cts.Cancel();
            WhenCancelled(cts.Token).Wait();
        }

        /// <summary>
        /// Handles cleanup operations when app is cancelled or unloads
        /// </summary>
        public static Task WhenCancelled(CancellationToken cancellationToken)
        {
            var tcs = new TaskCompletionSource<bool>();
            cancellationToken.Register(s => ((TaskCompletionSource<bool>)s).SetResult(true), tcs);
            return tcs.Task;
        }

        /// <summary>
        /// Initializes the ModuleClient and sets up the callback to receive
        /// messages containing temperature information
        /// </summary>
        static async Task Init()
        {
            MqttTransportSettings mqttSetting = new MqttTransportSettings(TransportType.Mqtt_Tcp_Only);
            ITransportSettings[] settings = { mqttSetting };

            // Open a connection to the Edge runtime
            ioTHubModuleClient = await ModuleClient.CreateFromEnvironmentAsync(settings).ConfigureAwait(false);
            await ioTHubModuleClient.OpenAsync().ConfigureAwait(false);
            Console.WriteLine("IoT Hub module client initialized.");

            // Read the TemperatureThreshold value from the module twin's desired properties
            var moduleTwin = await ioTHubModuleClient.GetTwinAsync().ConfigureAwait(false);
            await OnDesiredPropertiesUpdate(moduleTwin.Properties.Desired, ioTHubModuleClient);

            // Attach a callback for updates to the module twin's desired properties.
            await ioTHubModuleClient.SetDesiredPropertyUpdateCallbackAsync(OnDesiredPropertiesUpdate, null).ConfigureAwait(false);

            // Register a callback for messages that are received by the module.
            await ioTHubModuleClient.SetInputMessageHandlerAsync("input1", FilterMessagesAsync, ioTHubModuleClient).ConfigureAwait(false);
            
            await ioTHubModuleClient.SetMethodHandlerAsync(healthCheck, HealthCheckAsync, ioTHubModuleClient).ConfigureAwait(false);
            Console.WriteLine("Set Healthcheck Method Handler:HealthCheckAsync.");
        }

        static Task OnDesiredPropertiesUpdate(TwinCollection desiredProperties, object userContext)
        {
            const string tempThresholdProperty = "TemperatureThreshold";
            try
            {
                Console.WriteLine("Desired property change:");
                Console.WriteLine(JsonConvert.SerializeObject(desiredProperties));

                if (desiredProperties[tempThresholdProperty] != null)
                    temperatureThreshold = desiredProperties[tempThresholdProperty];

            }
            catch (AggregateException ex)
            {
                foreach (Exception exception in ex.InnerExceptions)
                {
                    Console.WriteLine();
                    Console.WriteLine($"Error receiving desired property: {exception}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.WriteLine($"Error receiving desired property: {ex}");
            }

            return Task.CompletedTask;
        }

        public static async Task<MessageResponse> FilterMessagesAsync(Message message, object userContext)
        {
            try
            {
                ModuleClient moduleClient = (ModuleClient)userContext;

                var filteredMessage = Filter(message);

                if (filteredMessage != null)
                {
                    await moduleClient.SendEventAsync("output1", filteredMessage).ConfigureAwait(false);
                }

                // Indicate that the message treatment is completed.
                return MessageResponse.Completed;
            }
            catch (AggregateException ex)
            {
                foreach (Exception exception in ex.InnerExceptions)
                {
                    Console.WriteLine();
                    Console.WriteLine($"Error in sample: {exception}");
                }

                // Indicate that the message treatment is not completed.
                return MessageResponse.Abandoned;
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.WriteLine($"Error in sample: {ex}");

                // Indicate that the message treatment is not completed.
                return MessageResponse.Abandoned;
            }
        }

        public static Message Filter(Message message)
        {
            var counterValue = Interlocked.Increment(ref counter);
            var messageBytes = message.GetBytes();
            var messageString = Encoding.UTF8.GetString(messageBytes);
            Console.WriteLine($"Received message {counterValue}: [{messageString}]");

            // Get message body
            var messageBody = JsonConvert.DeserializeObject<MessageBody>(messageString);

            if (messageBody != null && messageBody.machine.temperature > temperatureThreshold)
            {
                Console.WriteLine($"Machine temperature {messageBody.machine.temperature} exceeds threshold {temperatureThreshold}");
                var filteredMessage = new Message(messageBytes)
                {
                    ContentType = message.ContentType ?? "application/json",
                    ContentEncoding = message.ContentEncoding ?? "utf-8",
                };

                foreach (KeyValuePair<string, string> prop in message.Properties)
                {
                    filteredMessage.Properties.Add(prop.Key, prop.Value);
                }

                filteredMessage.Properties.Add("MessageType", "Alert");
                return filteredMessage;
            }

            return null;
        }

        private static async Task<MethodResponse> HealthCheckAsync(MethodRequest methodRequest, object userContext)
        {
            Console.WriteLine($"Received method [{methodRequest.Name}]");
            var request = JsonConvert.DeserializeObject<HealthCheckRequestPayload>(methodRequest.DataAsJson);

            var messageBody = Encoding.UTF8.GetBytes($"Device [{Environment.GetEnvironmentVariable("IOTEDGE_DEVICEID")}], Module [FilterModule] Running");

            var healthCheckMessage = new Message(messageBody);
            healthCheckMessage.Properties.Add("MessageType", healthCheck);
            if (!string.IsNullOrEmpty(request.CorrelationId))
                healthCheckMessage.Properties.Add("correlationId", request.CorrelationId);

            await ioTHubModuleClient.SendEventAsync(healthCheck, healthCheckMessage).ConfigureAwait(false);
            Console.WriteLine($"Sent method response via event [{healthCheck}]");

            var responseMsg = JsonConvert.SerializeObject(new HealthCheckResponsePayload() { ModuleResponse = string.IsNullOrEmpty(request.CorrelationId)? "":$"Invoked with correlationId:{request.CorrelationId}" });
            return new MethodResponse(Encoding.UTF8.GetBytes(responseMsg), 200);
        }
    }

      class HealthCheckRequestPayload
    {
        public string CorrelationId { get; set; }
        public string Text { get; set; }
    }

    class HealthCheckResponsePayload
    {
        public string ModuleResponse { get; set; } = null;
    }

}