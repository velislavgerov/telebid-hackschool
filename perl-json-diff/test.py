from jsonpatch import JsonPatch, JsonPatchConflict, JsonPointerException
import json

if __name__ == '__main__':
    print("Well, hello, again!")
    print("Open file: out.json")
    file = open('out.json', 'r')
    out = json.load(file)
    file.close()

    fail = 0
    ok = 0
    for data in out:
        patch = JsonPatch(data['patch'])
        try:
            result = patch.apply(data['src'])
        except (JsonPatchConflict, TypeError, JsonPointerException) as err:
            print(data['patch'])
            print(data['src'])
            print(data['dst'])
            print(err)
            print("FAIL")
            fail += 1
            continue
        if result == data['dst']:
            ok += 1
        else:
            fail +=1
            print(data['patch'])
            print(data['src'])
            print(data['dst'])
            print(result)

    print("Fail {}".format(fail))
    print("OK   {}".format(ok))
        

