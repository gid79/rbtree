
import java.util.*;

/**
 * Simple java benchmark implementation to verify the jruby implementation against.
 */
public class TreeMapReference {
  
  public static TreeMap<String,String> insert(List<String> keys) {
    TreeMap<String,String> map = new TreeMap<>();
    
    for ( String item : keys ) {
      map.put( item, item );
    }                       
    
    return map;
  }            
  
  public static void get(Map<String,String> map, List<String> keys) {
    for ( String item : keys ) {
      if ( !map.get( item ).equals( item ) ) {
        throw new AssertionError( "item [" + item  + "] not equal to self in map : [" + map.get( item ) + "]");
      }
    }                       
  }

  public static void remove(Map<String,String> map, List<String> keys) {
    for ( String item : keys ) {
      map.remove( item );
    }
  }

}