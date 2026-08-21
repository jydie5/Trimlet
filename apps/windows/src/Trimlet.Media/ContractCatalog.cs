using System.Text.Json;
using System.Text.Json.Serialization;

namespace Trimlet.Media;

public sealed record ContractError(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("retryable")] bool Retryable);

public sealed record ErrorCodeContract(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("errors")] IReadOnlyList<ContractError> Errors);

public static class ContractCatalog
{
    public static ErrorCodeContract ReadErrorCodes(Stream json)
    {
        var contract = JsonSerializer.Deserialize<ErrorCodeContract>(json)
            ?? throw new InvalidDataException("The error-code contract is empty.");

        if (contract.SchemaVersion != 1)
        {
            throw new InvalidDataException("Only error-code schema version 1 is supported.");
        }

        if (contract.Errors.Count == 0 || contract.Errors.Any(error => string.IsNullOrWhiteSpace(error.Id)))
        {
            throw new InvalidDataException("The error-code contract contains an invalid entry.");
        }

        if (contract.Errors.Select(error => error.Id).Distinct(StringComparer.Ordinal).Count() != contract.Errors.Count)
        {
            throw new InvalidDataException("Error identifiers must be unique.");
        }

        return contract;
    }
}
