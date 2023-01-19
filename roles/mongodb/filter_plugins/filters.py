class FilterModule(object):
    def filters(self):
        return {
            'move_in_list': move_in_list
        }

def move_in_list(instances, instance, delta):
    """
    Get an element in list using delta position from a reference element. Circle back to start or end if getting out of list
    """
    i = instances.index(instance)
    l = len(instances)
    r = i + delta
    if r<0:
        return instances[r+l]
    elif r>=l:
        return instances[r-l]
    else:
        return instances[r]

