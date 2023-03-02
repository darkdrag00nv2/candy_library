import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int8 "mo:base/Int8";
import Int16 "mo:base/Int16";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Bool "mo:base/Bool";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Types "types";
import CandyHex "hex";

import CandidTypes "mo:candid/Type";
import Arg "mo:candid/Arg";
import Value "mo:candid/Value";

module {
  //convert a candy value to JSON
  public func value_to_candid(val : Types.CandyValue) : [Arg.Arg] {
    let buffer = Buffer.Buffer<Arg.Arg>(0);
    switch (val) {
      //nat
      case (#Nat(val)) buffer.add({ _type = #nat; value = #nat(val) });
      case (#Nat64(val)) buffer.add({ _type = #nat64; value = #nat64(val) });
      case (#Nat32(val)) buffer.add({ _type = #nat32; value = #nat32(val) });
      case (#Nat16(val)) buffer.add({ _type = #nat16; value = #nat16(val) });
      case (#Nat8(val)) buffer.add({ _type = #nat8; value = #nat8(val) });
      //text
      case (#Text(val)) buffer.add({ _type = #text; value = #text(val) });
      //class
      case (#Class(val)) {
        let types : Buffer.Buffer<CandidTypes.RecordFieldType> = Buffer.Buffer<CandidTypes.RecordFieldType>(val.size());
        let body : Buffer.Buffer<Value.RecordFieldValue> = Buffer.Buffer<Value.RecordFieldValue>(val.size());
        for (this_item in val.vals()) {
          types.add({
            tag = #name(this_item.name);
            _type = (value_to_candid(this_item.value))[0]._type;
          });
          body.add({
            tag = #name(this_item.name);
            value = (value_to_candid(this_item.value))[0].value;
          });
        };
        buffer.add({
          _type = #record(Buffer.toArray(types));
          value = #record(Buffer.toArray(body));
        });
      };
      //array
      case (#Array(val)) {
        let list = switch (val) {
          case (#frozen(val)) val;
          case (#thawed(val)) val;
        };
        var bFoundMultipleTypes = false;
        var lastType : ?CandidTypes.Type = null;
        let values : Buffer.Buffer<Value.Value> = Buffer.Buffer<Value.Value>(list.size());
        let types : Buffer.Buffer<CandidTypes.RecordFieldType> = Buffer.Buffer<CandidTypes.RecordFieldType>(list.size());
        let body : Buffer.Buffer<Value.RecordFieldValue> = Buffer.Buffer<Value.RecordFieldValue>(list.size());
        var tracker : Nat32 = 0;
        for (this_item in list.vals()) {
          let item = (value_to_candid(this_item))[0];
          switch (lastType) {
            case (null) lastType := ?item._type;
            case (?lastType) {
              if (CandidTypes.equal(lastType, item._type)) {
              } else {
                bFoundMultipleTypes := true;
              };
            };
          };
          types.add({ _type = item._type; tag = #hash(tracker) });
          body.add({ tag = #hash(tracker); value = item.value });
          values.add(item.value);
          tracker += 1;
        };

        if (bFoundMultipleTypes) {
          //need to make a record
          buffer.add({
            _type = #record(Buffer.toArray(types));
            value = #record(Buffer.toArray(body));
          });
        } else {
          let thisType = switch (lastType) {
            case (null) #_null;
            case (?val) val;
          };
          buffer.add({
            _type = #vector(thisType);
            value = #vector(Buffer.toArray(values));
          });
        };
      };
      case (#Option(val)) {
        switch (val) {
          case (null) {
            buffer.add({ _type = #opt(#_null); value = #_null });
          };
          case (?val) {
            let item = (value_to_candid(val))[0];
            buffer.add({ _type = #opt(item._type); value = #opt(?item.value) });
          };
        };
      };
      case (#Nats(val)) {
        let list = switch (val) {
          case (#frozen(val)) val;
          case (#thawed(val)) val;
        };

        let values : Buffer.Buffer<Value.Value> = Buffer.Buffer<Value.Value>(list.size());
        for (this_item in list.vals()) {
          values.add(#nat(this_item));
        };
        buffer.add({ _type = #vector(#nat); value = #vector(Buffer.toArray(values)) });
      };
      case (#Floats(val)) {
        let list = switch (val) {
          case (#frozen(val)) val;
          case (#thawed(val)) val;
        };

        let values : Buffer.Buffer<Value.Value> = Buffer.Buffer<Value.Value>(list.size());
        for (this_item in list.vals()) {
          values.add(#float64(this_item));
        };

        buffer.add({
          _type = #vector(#float64);
          value = #vector(Buffer.toArray(values));
        });
      };
      //bytes
      case (#Bytes(val)) {
        let list = switch (val) {
          case (#frozen(val)) val;
          case (#thawed(val)) val;
        };

        let values : Buffer.Buffer<Value.Value> = Buffer.Buffer<Value.Value>(list.size());
        for (this_item in list.vals()) {
          values.add(#nat8(this_item));
        };
        buffer.add({ _type = #vector(#nat8); value = #vector(Buffer.toArray(values)) });
      };
      //bytes
      case (#Blob(val)) {
        let list = Blob.toArray(val);
        let values : Buffer.Buffer<Value.Value> = Buffer.Buffer<Value.Value>(list.size());
        for (this_item in list.vals()) {
          values.add(#nat8(this_item));
        };
        buffer.add({ _type = #vector(#nat8); value = #vector(Buffer.toArray(values)) });
      };
      //principal
      case (#Principal(val)) buffer.add({
        _type = #principal;
        value = #principal(#transparent(val));
      });
      //bool
      case (#Bool(val)) buffer.add({ _type = #bool; value = #bool(val) });
      //float
      case (#Float(val)) buffer.add({ _type = #float64; value = #float64(val) });
      case (#Empty) buffer.add({ _type = #empty; value = #empty });
      case (#Int(val)) buffer.add({ _type = #int; value = #int(val) });
      case (#Int64(val)) buffer.add({ _type = #int64; value = #int64(val) });
      case (#Int32(val)) buffer.add({ _type = #int32; value = #int32(val) });
      case (#Int16(val)) buffer.add({ _type = #int16; value = #int16(val) });
      case (#Int8(val)) buffer.add({ _type = #int8; value = #int8(val) });
    };

    Buffer.toArray(buffer);
  };
};
